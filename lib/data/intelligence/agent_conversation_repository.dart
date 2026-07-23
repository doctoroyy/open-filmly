import 'dart:convert';

import 'package:drift/drift.dart';

import 'agent_models.dart';
import 'intelligence_database.dart';

/// Persistence for the visible Filmly Conversations transcript. This
/// repository never reaches into the core media database and never stores
/// raw provider requests or credentials.
class AgentConversationRepository {
  AgentConversationRepository(this._database);

  final IntelligenceDatabase _database;

  Future<AgentConversation> create({
    required String id,
    required String title,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    final timestamp = now.toIso8601String();
    await _database
        .into(_database.agentConversations)
        .insert(
          AgentConversationsCompanion.insert(
            id: id,
            title: title,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    return (await getById(id))!;
  }

  Future<AgentConversation?> getById(String id) async {
    final row = await (_database.select(
      _database.agentConversations,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toConversation(row);
  }

  Future<List<AgentConversation>> list({
    bool includeArchived = false,
    int? limit,
  }) async {
    final query = _database.select(_database.agentConversations)
      ..orderBy([
        (item) => OrderingTerm.desc(item.pinnedAt),
        (item) => OrderingTerm.desc(item.updatedAt),
      ]);
    if (!includeArchived) {
      query.where((item) => item.archivedAt.isNull());
    }
    if (limit != null) query.limit(limit);
    final rows = await query.get();
    return rows.map(_toConversation).toList(growable: false);
  }

  Future<List<AgentConversationMessage>> listMessages(
    String conversationId,
  ) async {
    final rows =
        await (_database.select(_database.agentConversationMessages)
              ..where((item) => item.conversationId.equals(conversationId))
              ..orderBy([(item) => OrderingTerm.asc(item.sequence)]))
            .get();
    return rows.map(_toMessage).toList(growable: false);
  }

  /// Conversation ids that currently have at least one attached plan card.
  /// Used only for rail status dots; it never loads full plan payloads.
  Future<Set<String>> conversationIdsWithPlans() async {
    final conversationId = _database.agentConversationMessages.conversationId;
    final rows = await (_database.selectOnly(_database.agentConversationMessages)
          ..addColumns([conversationId])
          ..where(_database.agentConversationMessages.planId.isNotNull()))
        .get();
    return {
      for (final row in rows) ?row.read(conversationId),
    };
  }

  Future<AgentConversationMessage> appendMessage({
    required String conversationId,
    required String id,
    required AgentConversationRole role,
    required String content,
    List<String> toolsUsed = const [],
    String? planId,
    AgentConversationMessageStatus status =
        AgentConversationMessageStatus.complete,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    return _database
        .transaction(() async {
          final sequence = await _nextSequence(conversationId);
          await _database
              .into(_database.agentConversationMessages)
              .insert(
                AgentConversationMessagesCompanion.insert(
                  id: id,
                  conversationId: conversationId,
                  sequence: sequence,
                  role: role.name,
                  content: content,
                  toolsJson: Value(
                    toolsUsed.isEmpty ? null : jsonEncode(toolsUsed),
                  ),
                  planId: Value(planId),
                  status: Value(status.name),
                  createdAt: now.toIso8601String(),
                ),
              );
          await (_database.update(
            _database.agentConversations,
          )..where((item) => item.id.equals(conversationId))).write(
            AgentConversationsCompanion(
              preview: Value(_previewFor(content)),
              updatedAt: Value(now.toIso8601String()),
            ),
          );
          return (await (_database.select(
            _database.agentConversationMessages,
          )..where((item) => item.id.equals(id))).getSingle());
        })
        .then(_toMessage);
  }

  Future<void> rename(String id, String title) {
    final value = title.trim();
    if (value.isEmpty) return Future.value();
    return (_database.update(
      _database.agentConversations,
    )..where((item) => item.id.equals(id))).write(
      AgentConversationsCompanion(
        title: Value(value),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> setPinned(String id, {required bool pinned}) {
    final now = DateTime.now().toIso8601String();
    return (_database.update(
      _database.agentConversations,
    )..where((item) => item.id.equals(id))).write(
      AgentConversationsCompanion(
        pinnedAt: Value(pinned ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> setArchived(String id, {required bool archived}) {
    final now = DateTime.now().toIso8601String();
    return (_database.update(
      _database.agentConversations,
    )..where((item) => item.id.equals(id))).write(
      AgentConversationsCompanion(
        archivedAt: Value(archived ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Conversation deletion intentionally leaves agent runs, smart
  /// collections, subtitle artifacts, and all core library data untouched.
  Future<void> deleteById(String id) => _database.transaction(() async {
    await (_database.delete(
      _database.agentConversationMessages,
    )..where((item) => item.conversationId.equals(id))).go();
    await (_database.delete(
      _database.agentConversations,
    )..where((item) => item.id.equals(id))).go();
  });

  Future<int> _nextSequence(String conversationId) async {
    final maxSequence = _database.agentConversationMessages.sequence.max();
    final row =
        await (_database.selectOnly(_database.agentConversationMessages)
              ..addColumns([maxSequence])
              ..where(
                _database.agentConversationMessages.conversationId.equals(
                  conversationId,
                ),
              ))
            .getSingle();
    return (row.read(maxSequence) ?? -1) + 1;
  }

  AgentConversation _toConversation(AgentConversationRow row) =>
      AgentConversation(
        id: row.id,
        title: row.title,
        preview: row.preview,
        pinnedAt: _parseDate(row.pinnedAt),
        archivedAt: _parseDate(row.archivedAt),
        createdAt:
            _parseDate(row.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            _parseDate(row.updatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  AgentConversationMessage _toMessage(AgentConversationMessageRow row) =>
      AgentConversationMessage(
        id: row.id,
        conversationId: row.conversationId,
        sequence: row.sequence,
        role: AgentConversationRole.fromName(row.role),
        content: row.content,
        toolsUsed: _decodeStringList(row.toolsJson),
        planId: row.planId,
        status: AgentConversationMessageStatus.fromName(row.status),
        createdAt:
            _parseDate(row.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded.map((item) => item.toString()).toList(growable: false)
          : const [];
    } catch (_) {
      return const [];
    }
  }

  String _previewFor(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 96 ? normalized : normalized.substring(0, 96);
  }
}
