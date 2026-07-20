import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_job_service.dart';
import 'ai_provider.dart';
import 'media_identity_service.dart';
import 'subtitle_generation_service.dart';
import 'transcript_correction_service.dart';
import '../../data/intelligence/ai_job_repository.dart';
import '../../data/intelligence/intelligence_asset_repository.dart';
import '../../data/intelligence/intelligence_models.dart';
import 'transcript_service.dart';
import 'scene_index_service.dart';
import 'ai_job_scheduler.dart';

class GeneratedSubtitleResult {
  const GeneratedSubtitleResult({
    required this.identity,
    required this.transcriptionJob,
    required this.sourceLanguage,
    required this.outputLanguage,
    required this.translated,
    required this.artifacts,
    this.translationJob,
  });

  final MediaIdentity identity;
  final AiJob transcriptionJob;
  final AiJob? translationJob;
  final String sourceLanguage;
  final String outputLanguage;
  final bool translated;
  final List<SubtitleArtifact> artifacts;
}

class MediaIntelligenceService {
  MediaIntelligenceService({
    required this.assets,
    required this.jobs,
    required this.jobService,
    required this.transcripts,
    required this.provider,
    this.sceneIndex,
    this.scheduler,
    this.correction = const TranscriptCorrectionService(),
  });

  final IntelligenceAssetRepository assets;
  final AiJobRepository jobs;
  final AiJobService jobService;
  final TranscriptService transcripts;
  final AiProvider provider;
  final SceneIndexService? sceneIndex;
  final AiJobScheduler? scheduler;
  var _schedulerStarted = false;
  final TranscriptCorrectionService correction;

  Future<AiJob> transcribeLocalFile({
    required String path,
    required String model,
    required String language,
    String? mediaId,
    String? episodeId,
    bool force = false,
  }) async {
    final identity = await MediaIdentityService.fromFile(path: path);
    await assets.upsert(
      identity: identity,
      mediaId: mediaId,
      episodeId: episodeId,
      status: 'pending',
    );
    final queued = await jobs.enqueue(
      assetId: identity.identityKey,
      taskType: AiTaskType.transcribe,
      model: model,
      force: force,
    );
    final queue = scheduler;
    if (queue == null) {
      await jobService.runJob(queued.id, (job, onProgress) async {
        await _transcribeJob(
          job,
          onProgress,
          fallbackPath: path,
          fallbackLanguage: language,
        );
      });
    } else {
      await _ensureScheduler(queue);
      await queue.wake();
      await _waitForTerminal(queued.id);
    }
    return (await jobs.getById(queued.id))!;
  }

  /// Runs the complete first-release subtitle pipeline and writes external
  /// subtitle artifacts without touching the user's media directory.
  Future<GeneratedSubtitleResult> generateSubtitlesForLocalFile({
    required String path,
    required String model,
    required String sourceLanguage,
    required String targetLanguage,
    String? mediaId,
    String? episodeId,
    Directory? outputDirectory,
    bool force = false,
  }) async {
    final transcriptionJob = await transcribeLocalFile(
      path: path,
      model: model,
      language: sourceLanguage,
      mediaId: mediaId,
      episodeId: episodeId,
      force: force,
    );
    if (transcriptionJob.status != AiJobStatus.succeeded) {
      throw StateError(
        'Transcription failed: ${transcriptionJob.error ?? transcriptionJob.status.name}',
      );
    }

    final identity = await MediaIdentityService.fromFile(path: path);
    final rows = await transcripts.getByAsset(identity.identityKey);
    final detectedLanguage = rows
        .map((segment) => segment.language.trim())
        .firstWhere(
          (language) => language.isNotEmpty,
          orElse: () => sourceLanguage,
        );
    AiJob? translationJob;
    if (rows.isNotEmpty &&
        targetLanguage.trim().isNotEmpty &&
        !_sameLanguage(detectedLanguage, targetLanguage)) {
      translationJob = await translateAsset(
        assetId: identity.identityKey,
        sourceLanguage: detectedLanguage,
        targetLanguage: targetLanguage,
        model: model,
        force: force,
      );
    }

    final translated =
        targetLanguage.trim().isNotEmpty &&
        (await transcripts.getByAsset(
          identity.identityKey,
        )).any((segment) => segment.translatedText?.trim().isNotEmpty == true);
    final outputLanguage = translated
        ? targetLanguage.trim()
        : (detectedLanguage.isEmpty ? 'source' : detectedLanguage);
    final artifacts = await SubtitleGenerationService(transcripts)
        .writeArtifacts(
          assetId: identity.identityKey,
          language: outputLanguage,
          directory: outputDirectory,
          translated: translated,
        );
    return GeneratedSubtitleResult(
      identity: identity,
      transcriptionJob: transcriptionJob,
      translationJob: translationJob,
      sourceLanguage: detectedLanguage,
      outputLanguage: outputLanguage,
      translated: translated,
      artifacts: artifacts,
    );
  }

  Future<AiJob> translateAsset({
    required String assetId,
    required String sourceLanguage,
    required String targetLanguage,
    required String model,
    bool force = false,
  }) async {
    final queued = await jobs.enqueue(
      assetId: assetId,
      taskType: AiTaskType.translate,
      model: '$model:$targetLanguage',
      force: force,
    );
    final queue = scheduler;
    if (queue == null) {
      await jobService.runJob(queued.id, (job, onProgress) async {
        await _translateJob(job, onProgress, sourceLanguage: sourceLanguage);
      });
    } else {
      await _ensureScheduler(queue);
      await queue.wake();
      await _waitForTerminal(queued.id);
    }
    return (await jobs.getById(queued.id))!;
  }

  Future<AiJob> probeAsset({required String assetId, bool force = false}) {
    return _runQueuedTask(
      assetId: assetId,
      taskType: AiTaskType.probe,
      model: 'probe',
      force: force,
    );
  }

  Future<AiJob> sampleFramesAsset({
    required String assetId,
    required String outputDirectory,
    required int durationMs,
    int count = 12,
    bool force = false,
  }) {
    return _runQueuedTask(
      assetId: assetId,
      taskType: AiTaskType.sampleFrames,
      model: jsonEncode({
        'outputDirectory': outputDirectory,
        'durationMs': durationMs,
        'count': count,
      }),
      force: force,
    );
  }

  Future<AiJob> indexScenesAsset({
    required String assetId,
    bool force = false,
  }) {
    return _runQueuedTask(
      assetId: assetId,
      taskType: AiTaskType.sceneIndex,
      model: 'transcript-window-v1',
      force: force,
    );
  }

  Future<void> _transcribeJob(
    AiJob job,
    Future<void> Function(double progress, {String? checkpoint}) onProgress, {
    String? fallbackPath,
    String fallbackLanguage = 'auto',
  }) async {
    final asset = await assets.getById(job.assetId);
    final path = fallbackPath ?? asset?.canonicalUri;
    if (path == null || path.isEmpty) throw StateError('媒体身份没有可用路径');
    final result = await provider.transcribe(
      path: path,
      language: fallbackLanguage,
      model: job.model,
      onProgress: (progress) => onProgress(progress),
    );
    await transcripts.saveProviderResult(
      job.assetId,
      correction.correct(result),
    );
    await sceneIndex?.indexAsset(job.assetId);
  }

  Future<void> _translateJob(
    AiJob job,
    Future<void> Function(double progress, {String? checkpoint}) onProgress, {
    required String sourceLanguage,
  }) async {
    final separator = job.model.lastIndexOf(':');
    final targetLanguage = separator >= 0
        ? job.model.substring(separator + 1)
        : job.model;
    final segments = await transcripts.getByAsset(job.assetId);
    final result = await provider.translate(
      texts: segments.map((segment) => segment.text).toList(growable: false),
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      model: separator >= 0 ? job.model.substring(0, separator) : job.model,
      onProgress: (progress) => onProgress(progress),
    );
    await transcripts.saveTranslations(job.assetId, result);
  }

  Future<void> _ensureScheduler(AiJobScheduler queue) async {
    if (_schedulerStarted) return;
    await queue.recoverAndWake();
    await queue.start(_dispatchJob);
    _schedulerStarted = true;
  }

  Future<void> _dispatchJob(
    AiJob job,
    Future<void> Function(double progress, {String? checkpoint}) onProgress,
  ) async {
    switch (job.taskType) {
      case AiTaskType.transcribe:
        await _transcribeJob(job, onProgress);
      case AiTaskType.translate:
        final segments = await transcripts.getByAsset(job.assetId);
        final source = segments
            .map((segment) => segment.language.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => 'auto');
        await _translateJob(job, onProgress, sourceLanguage: source);
      case AiTaskType.probe:
        final asset = await assets.getById(job.assetId);
        final path = asset?.canonicalUri;
        if (path == null || path.isEmpty) {
          throw StateError('媒体身份没有可用路径');
        }
        final result = await provider.probe(
          path,
          onProgress: (progress) => onProgress(progress),
        );
        await onProgress(1, checkpoint: jsonEncode(result));
      case AiTaskType.sampleFrames:
        final asset = await assets.getById(job.assetId);
        final path = asset?.canonicalUri;
        if (path == null || path.isEmpty) {
          throw StateError('媒体身份没有可用路径');
        }
        final options = _decodeOptions(job.model);
        final paths = await provider.sampleFrames(
          path: path,
          outputDirectory: options['outputDirectory']?.toString() ?? '',
          durationMs: (options['durationMs'] as num?)?.round() ?? 0,
          count: (options['count'] as num?)?.round() ?? 12,
          onProgress: (progress) => onProgress(progress),
        );
        await sceneIndex?.attachScreenshots(job.assetId, paths);
        await onProgress(1, checkpoint: jsonEncode({'paths': paths}));
      case AiTaskType.sceneIndex:
        if (sceneIndex == null) {
          throw StateError('场景索引服务未配置');
        }
        final count = await sceneIndex!.indexAsset(job.assetId);
        await onProgress(1, checkpoint: jsonEncode({'sceneCount': count}));
      case AiTaskType.embed:
        throw StateError('向量索引任务将在下一阶段接入');
    }
  }

  Future<AiJob> _runQueuedTask({
    required String assetId,
    required AiTaskType taskType,
    required String model,
    required bool force,
  }) async {
    final queued = await jobs.enqueue(
      assetId: assetId,
      taskType: taskType,
      model: model,
      force: force,
    );
    final queue = scheduler;
    if (queue == null) {
      await jobService.runJob(queued.id, _dispatchJob);
    } else {
      await _ensureScheduler(queue);
      await queue.wake();
      await _waitForTerminal(queued.id);
    }
    return (await jobs.getById(queued.id))!;
  }

  Map<String, dynamic> _decodeOptions(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<AiJob> _waitForTerminal(String id) async {
    for (var i = 0; i < 300; i++) {
      final job = await jobs.getById(id);
      if (job == null) throw StateError('任务不存在：$id');
      if (job.status == AiJobStatus.succeeded ||
          job.status == AiJobStatus.failed ||
          job.status == AiJobStatus.cancelled) {
        return job;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('AI 任务等待超时：$id');
  }

  bool _sameLanguage(String left, String right) {
    String base(String value) =>
        value.trim().toLowerCase().split(RegExp(r'[-_]')).first;
    return left.isNotEmpty && right.isNotEmpty && base(left) == base(right);
  }
}
