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
    this.correction = const TranscriptCorrectionService(),
  });

  final IntelligenceAssetRepository assets;
  final AiJobRepository jobs;
  final AiJobService jobService;
  final TranscriptService transcripts;
  final AiProvider provider;
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
    await jobService.runJob(queued.id, (job, onProgress) async {
      final result = await provider.transcribe(
        path: path,
        language: language,
        model: model,
        onProgress: (progress) => onProgress(progress),
      );
      await transcripts.saveProviderResult(
        job.assetId,
        correction.correct(result),
      );
    });
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
    await jobService.runJob(queued.id, (job, onProgress) async {
      final segments = await transcripts.getByAsset(assetId);
      final result = await provider.translate(
        texts: segments.map((segment) => segment.text).toList(growable: false),
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        model: model,
        onProgress: (progress) => onProgress(progress),
      );
      await transcripts.saveTranslations(assetId, result);
    });
    return (await jobs.getById(queued.id))!;
  }

  bool _sameLanguage(String left, String right) {
    String base(String value) =>
        value.trim().toLowerCase().split(RegExp(r'[-_]')).first;
    return left.isNotEmpty && right.isNotEmpty && base(left) == base(right);
  }
}
