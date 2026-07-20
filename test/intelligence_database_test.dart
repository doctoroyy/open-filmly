import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/intelligence_models.dart';
import 'package:open_filmly/data/intelligence/ai_job_repository.dart';

void main() {
  late IntelligenceDatabase database;
  late AiJobRepository repository;

  setUp(() {
    database = IntelligenceDatabase.inMemory();
    repository = AiJobRepository(database);
  });

  tearDown(() async => database.close());

  test('creates an isolated intelligence database and enqueues idempotently', () async {
    final first = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );
    final second = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );

    expect(first.id, second.id);
    expect((await repository.list()).length, 1);
    expect(first.status, AiJobStatus.queued);
  });

  test('resets interrupted work and preserves retry state', () async {
    final job = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );
    await repository.markRunning(job.id);
    await repository.updateProgress(job.id, 0.4, checkpoint: 'segment-4');
    await repository.resetInterrupted();

    final recovered = await repository.getById(job.id);
    expect(recovered?.status, AiJobStatus.queued);
    expect(recovered?.progress, 0.4);
    expect(recovered?.checkpoint, 'segment-4');
  });

  test('force enqueue creates a new attempt after a failure', () async {
    final job = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );
    await repository.fail(job.id, 'worker crashed');

    final retried = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
      force: true,
    );

    expect(retried.id, job.id);
    expect(retried.status, AiJobStatus.queued);
    expect(retried.attempts, 1);
  });
}
