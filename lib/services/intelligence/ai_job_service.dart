import '../../data/intelligence/ai_job_repository.dart';
import '../../data/intelligence/intelligence_models.dart';

typedef AiJobHandler =
    Future<void> Function(
      AiJob job,
      Future<void> Function(double progress, {String? checkpoint}) onProgress,
    );

class AiJobService {
  AiJobService(this._repository);

  final AiJobRepository _repository;
  bool _running = false;

  Future<AiJob?> runNext(AiJobHandler handler) async {
    if (_running) return null;
    final queued = await _repository.nextQueued();
    if (queued == null) return null;
    return runJob(queued.id, handler);
  }

  /// Runs the requested job without accidentally consuming another queued
  /// task. This is important for user-triggered, multi-step workflows such as
  /// transcription followed by translation.
  Future<AiJob?> runJob(String jobId, AiJobHandler handler) async {
    if (_running) return null;
    final queued = await _repository.getById(jobId);
    if (queued == null || queued.status != AiJobStatus.queued) return queued;
    _running = true;
    try {
      await _repository.markRunning(queued.id);
      final running = await _repository.getById(queued.id) ?? queued;
      await handler(running, (progress, {checkpoint}) {
        return _repository.updateProgress(
          running.id,
          progress,
          checkpoint: checkpoint,
        );
      });
      await _repository.succeed(running.id);
    } catch (error) {
      await _repository.fail(queued.id, error.toString());
    } finally {
      _running = false;
    }
    return _repository.getById(queued.id);
  }

  Future<void> recoverAfterRestart() => _repository.resetInterrupted();

  Future<void> cancel(String jobId) => _repository.cancel(jobId);

  Future<void> pause(String jobId) => _repository.pause(jobId);

  Future<void> resume(String jobId) => _repository.resume(jobId);

  Future<void> retry(String jobId) => _repository.retry(jobId);
}
