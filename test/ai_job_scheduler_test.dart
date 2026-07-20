import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/ai_job_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/intelligence_models.dart';
import 'package:open_filmly/services/intelligence/ai_job_scheduler.dart';

void main() {
  test('drains queued work serially after startup', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final repository = AiJobRepository(database);
    final first = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );
    final second = await repository.enqueue(
      assetId: 'asset-2',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );
    final order = <String>[];
    final scheduler = AiJobScheduler(repository);

    await scheduler.start((job, onProgress) async {
      order.add(job.id);
      await onProgress(1);
    });

    expect(order, [first.id, second.id]);
    expect(
      (await repository.list()).every(
        (job) => job.status == AiJobStatus.succeeded,
      ),
      isTrue,
    );
    await scheduler.stop();
  });

  test('recovers running jobs before draining', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final repository = AiJobRepository(database);
    final job = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );
    await repository.markRunning(job.id);
    final scheduler = AiJobScheduler(repository);
    final completed = Completer<void>();

    await repository.resetInterrupted();
    await scheduler.start((current, _) async {
      expect(current.id, job.id);
      completed.complete();
    });

    await completed.future;
    expect((await repository.getById(job.id))?.status, AiJobStatus.succeeded);
    await scheduler.stop();
  });
}
