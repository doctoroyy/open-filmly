import 'dart:convert';

import 'package:drift/drift.dart';

import 'intelligence_database.dart';

enum WatchEventKind {
  play,
  pause,
  progress,
  seek,
  skip,
  completed,
  repeat,
  abandon,
  favorite;

  static WatchEventKind fromName(String value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => WatchEventKind.progress,
  );
}

class WatchEvent {
  const WatchEvent({
    required this.id,
    required this.assetId,
    required this.kind,
    required this.positionMs,
    this.durationMs,
    required this.occurredAt,
    this.payload = const {},
  });

  final String id;
  final String assetId;
  final WatchEventKind kind;
  final int positionMs;
  final int? durationMs;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetId': assetId,
    'kind': kind.name,
    'positionMs': positionMs,
    if (durationMs != null) 'durationMs': durationMs,
    'occurredAt': occurredAt.toIso8601String(),
    'payload': payload,
  };
}

class WatchEventRepository {
  WatchEventRepository(this._database);

  final IntelligenceDatabase _database;

  Future<WatchEvent> record({
    required String assetId,
    required WatchEventKind kind,
    required int positionMs,
    int? durationMs,
    Map<String, dynamic> payload = const {},
    DateTime? occurredAt,
  }) async {
    final now = occurredAt ?? DateTime.now();
    final id =
        '${assetId.hashCode.abs()}-${now.microsecondsSinceEpoch}-${kind.name}';
    await _database
        .into(_database.watchEvents)
        .insert(
          WatchEventsCompanion.insert(
            id: id,
            assetId: assetId,
            kind: kind.name,
            positionMs: positionMs < 0 ? 0 : positionMs,
            durationMs: Value(durationMs),
            occurredAt: now.toIso8601String(),
            payload: Value(payload.isEmpty ? null : jsonEncode(payload)),
          ),
        );
    return WatchEvent(
      id: id,
      assetId: assetId,
      kind: kind,
      positionMs: positionMs < 0 ? 0 : positionMs,
      durationMs: durationMs,
      occurredAt: now,
      payload: payload,
    );
  }

  Future<List<WatchEvent>> list({String? assetId, int? limit}) async {
    final query = _database.select(_database.watchEvents)
      ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]);
    if (assetId != null && assetId.isNotEmpty) {
      query.where((row) => row.assetId.equals(assetId));
    }
    if (limit != null) query.limit(limit);
    final rows = await query.get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<void> clear() => _database.delete(_database.watchEvents).go();

  Future<String> exportJson() async {
    final events = await list();
    return jsonEncode({
      'formatVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'events': events.map((event) => event.toJson()).toList(),
    });
  }

  WatchEvent _toDomain(WatchEventRow row) {
    Map<String, dynamic> payload = const {};
    final raw = row.payload;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Ignore malformed optional payloads.
      }
    }
    return WatchEvent(
      id: row.id,
      assetId: row.assetId,
      kind: WatchEventKind.fromName(row.kind),
      positionMs: row.positionMs,
      durationMs: row.durationMs,
      occurredAt:
          DateTime.tryParse(row.occurredAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      payload: payload,
    );
  }
}
