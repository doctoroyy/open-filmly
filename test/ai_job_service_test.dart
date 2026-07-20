import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/ai_job_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/intelligence_models.dart';
import 'package:open_filmly/services/intelligence/ai_job_service.dart';

void main() {
  late IntelligenceDatabase database;
  late AiJobRepository repository;

  setUp(() {
    database = IntelligenceDatabase.inMemory();
    repository = AiJobRepository(database);
  });

  tearDown(() async => database.close());

  test('runs only one queued job and records progress', () async {
    final job = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );
    final service = AiJobService(repository);
    final progress = <double>[];

    final completed = await service.runNext(
      (current, onProgress) async {
        expect(current.id, job.id);
        await onProgress(0.5);
        progress.add(0.5);
      },
    );

    expect(completed?.status, AiJobStatus.succeeded);
    expect(progress, [0.5]);
    expect((await repository.getById(job.id))?.progress, 1);
  });

  test('turns handler errors into a failed job without throwing', () async {
    final job = await repository.enqueue(
      assetId: 'asset-1',
      taskType: AiTaskType.transcribe,
      model: 'tiny',
    );
    final service = AiJobService(repository);

    final completed = await service.runNext((_, _) async {
      throw StateError('worker unavailable');
    });

    expect(completed?.status, AiJobStatus.failed);
    expect((await repository.getById(job.id))?.error, contains('worker unavailable'));
  });
}
