import 'dart:convert';

import 'package:drift/drift.dart';

import 'agent_models.dart';
import 'intelligence_database.dart';

class AgentRunRepository {
  AgentRunRepository(this._database);

  final IntelligenceDatabase _database;

  Future<MediaAgentRun> create(MediaAgentPlan plan) async {
    final now = plan.createdAt.toIso8601String();
    await _database
        .into(_database.agentRuns)
        .insert(
          AgentRunsCompanion.insert(
            id: plan.id,
            operation: plan.operation.name,
            status: const Value('planned'),
            planJson: jsonEncode(plan.toJson()),
            previewJson: jsonEncode(
              plan.preview.map((item) => item.toJson()).toList(),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getById(plan.id))!;
  }

  Future<MediaAgentRun?> getById(String id) async {
    final row = await (_database.select(
      _database.agentRuns,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<MediaAgentRun>> list({int limit = 50}) async {
    final rows =
        await (_database.select(_database.agentRuns)
              ..orderBy([(item) => OrderingTerm.desc(item.updatedAt)])
              ..limit(limit))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<void> setStatus(
    String id,
    MediaAgentRunStatus status, {
    Map<String, dynamic>? result,
    String? error,
  }) async {
    await (_database.update(
      _database.agentRuns,
    )..where((item) => item.id.equals(id))).write(
      AgentRunsCompanion(
        status: Value(status.name),
        resultJson: result == null
            ? const Value.absent()
            : Value(jsonEncode(result)),
        error: Value(error),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> recoverInterrupted() async {
    await (_database.update(_database.agentRuns)..where(
          (item) => item.status.equals(MediaAgentRunStatus.running.name),
        ))
        .write(
          AgentRunsCompanion(
            status: const Value('confirmed'),
            updatedAt: Value(DateTime.now().toIso8601String()),
          ),
        );
  }

  MediaAgentRun _toDomain(AgentRunRow row) {
    final plan = MediaAgentPlan.fromJson(
      Map<String, dynamic>.from(jsonDecode(row.planJson) as Map),
    );
    final rawPreview = jsonDecode(row.previewJson);
    final rawResult = row.resultJson == null
        ? null
        : jsonDecode(row.resultJson!);
    return MediaAgentRun(
      id: row.id,
      operation: MediaAgentOperation.fromName(row.operation),
      status: MediaAgentRunStatus.fromName(row.status),
      plan: plan,
      preview: rawPreview is List
          ? rawPreview
                .whereType<Map>()
                .map(
                  (item) => AgentPreviewItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      result: rawResult is Map
          ? Map<String, dynamic>.from(rawResult)
          : const {},
      error: row.error,
      createdAt:
          DateTime.tryParse(row.createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(row.updatedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
