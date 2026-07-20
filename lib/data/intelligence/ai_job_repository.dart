import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'intelligence_database.dart';
import 'intelligence_models.dart';

class AiJobRepository {
  AiJobRepository(this._database);

  final IntelligenceDatabase _database;

  Future<AiJob> enqueue({
    required String assetId,
    required AiTaskType taskType,
    required String model,
    bool force = false,
  }) async {
    final id = sha256
        .convert(utf8.encode('$assetId|${taskType.name}|$model'))
        .toString();
    final existing = await getById(id);
    if (existing != null && !force) return existing;

    final now = DateTime.now().toIso8601String();
    final attempts = force && existing != null ? existing.attempts + 1 : 0;
    await _database
        .into(_database.aiJobs)
        .insertOnConflictUpdate(
          AiJobsCompanion.insert(
            id: id,
            assetId: assetId,
            type: taskType.name,
            model: model,
            status: const Value('queued'),
            progress: const Value(0),
            attempts: Value(attempts),
            checkpoint: const Value.absent(),
            error: const Value.absent(),
            createdAt: existing?.createdAt.toIso8601String() ?? now,
            updatedAt: now,
          ),
        );
    return (await getById(id))!;
  }

  Future<AiJob?> getById(String id) async {
    final row = await (_database.select(
      _database.aiJobs,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<AiJob>> list({AiJobStatus? status}) async {
    final query = _database.select(_database.aiJobs)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    if (status != null) {
      query.where((table) => table.status.equals(status.name));
    }
    final rows = await query.get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<AiJob?> nextQueued() async {
    final rows =
        await (_database.select(_database.aiJobs)
              ..where((table) => table.status.equals(AiJobStatus.queued.name))
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : _toDomain(rows.first);
  }

  Future<void> markRunning(String id) async {
    final current = await getById(id);
    if (current == null) return;
    await _update(
      id,
      AiJobsCompanion(
        status: const Value('running'),
        attempts: Value(current.attempts + 1),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> updateProgress(
    String id,
    double progress, {
    String? checkpoint,
  }) async {
    await _update(
      id,
      AiJobsCompanion(
        progress: Value(progress.clamp(0, 1)),
        checkpoint: Value(checkpoint),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> succeed(String id) async {
    await _update(
      id,
      AiJobsCompanion(
        status: const Value('succeeded'),
        progress: const Value(1),
        error: const Value.absent(),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> fail(String id, String error) async {
    await _update(
      id,
      AiJobsCompanion(
        status: const Value('failed'),
        error: Value(error),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> cancel(String id) async {
    await _update(
      id,
      AiJobsCompanion(
        status: const Value('cancelled'),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> pause(String id) async {
    await _update(
      id,
      AiJobsCompanion(
        status: const Value('paused'),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> resume(String id) async {
    final current = await getById(id);
    if (current == null ||
        (current.status != AiJobStatus.paused &&
            current.status != AiJobStatus.retryWait)) {
      return;
    }
    await _update(
      id,
      AiJobsCompanion(
        status: const Value('queued'),
        error: const Value(null),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> retry(String id) async {
    final current = await getById(id);
    if (current == null || current.status != AiJobStatus.failed) return;
    await _update(
      id,
      AiJobsCompanion(
        status: const Value('queued'),
        progress: const Value(0),
        error: const Value(null),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> resetInterrupted() async {
    await (_database.update(
      _database.aiJobs,
    )..where((table) => table.status.equals(AiJobStatus.running.name))).write(
      AiJobsCompanion(
        status: const Value('queued'),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> _update(String id, AiJobsCompanion companion) async {
    await (_database.update(
      _database.aiJobs,
    )..where((table) => table.id.equals(id))).write(companion);
  }

  AiJob _toDomain(AiJobRow row) => AiJob(
    id: row.id,
    assetId: row.assetId,
    taskType: AiTaskType.fromName(row.type),
    model: row.model,
    status: AiJobStatus.fromName(row.status),
    progress: row.progress,
    attempts: row.attempts,
    checkpoint: row.checkpoint,
    error: row.error,
    createdAt:
        DateTime.tryParse(row.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(row.updatedAt) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
