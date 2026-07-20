import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/ai_job_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_asset_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/intelligence_models.dart';
import 'package:open_filmly/data/intelligence/content_segment_repository.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/ai_job_service.dart';
import 'package:open_filmly/services/intelligence/ai_job_scheduler.dart';
import 'package:open_filmly/services/intelligence/media_intelligence_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';
import 'package:open_filmly/services/intelligence/scene_index_service.dart';

void main() {
  test(
    'runs transcription through the persistent scheduler and resolves the asset path',
    () async {
      final database = IntelligenceDatabase.inMemory();
      addTearDown(database.close);
      final file = await File(
        '${Directory.systemTemp.path}/filmly-ai-scheduled.mkv',
      ).writeAsString('fixture');
      addTearDown(() async => file.delete());
      final jobs = AiJobRepository(database);
      final scheduler = AiJobScheduler(jobs);
      addTearDown(scheduler.stop);
      final provider = FakeAiProvider();
      final service = MediaIntelligenceService(
        assets: IntelligenceAssetRepository(database),
        jobs: jobs,
        jobService: AiJobService(jobs),
        transcripts: TranscriptService(database),
        provider: provider,
        scheduler: scheduler,
      );

      final job = await service.transcribeLocalFile(
        path: file.path,
        model: 'tiny',
        language: 'en',
      );

      expect(job.status, AiJobStatus.succeeded);
      expect(provider.lastPath, file.path);
    },
  );

  test(
    'runs local transcription into the independent intelligence database',
    () async {
      final database = IntelligenceDatabase.inMemory();
      addTearDown(database.close);
      final file = await File(
        '${Directory.systemTemp.path}/filmly-ai-test.mkv',
      ).writeAsString('fixture');
      addTearDown(() async => file.delete());

      final provider = FakeAiProvider();
      final service = MediaIntelligenceService(
        assets: IntelligenceAssetRepository(database),
        jobs: AiJobRepository(database),
        jobService: AiJobService(AiJobRepository(database)),
        transcripts: TranscriptService(database),
        provider: provider,
      );

      final job = await service.transcribeLocalFile(
        path: file.path,
        model: 'tiny',
        language: 'en',
      );

      expect(job.status, AiJobStatus.succeeded);
      expect(provider.lastPath, file.path);
      expect(
        (await TranscriptService(database).getByAsset(job.assetId)).single.text,
        'hello',
      );
    },
  );

  test(
    'runs transcription, correction, translation, and writes both subtitle formats',
    () async {
      final database = IntelligenceDatabase.inMemory();
      addTearDown(database.close);
      final file = await File(
        '${Directory.systemTemp.path}/filmly-ai-pipeline.mkv',
      ).writeAsString('fixture');
      addTearDown(() async => file.delete());
      final output = await Directory.systemTemp.createTemp(
        'filmly-ai-artifacts-',
      );
      addTearDown(() async => output.delete(recursive: true));

      final provider = FakeAiProvider();
      final jobs = AiJobRepository(database);
      final service = MediaIntelligenceService(
        assets: IntelligenceAssetRepository(database),
        jobs: jobs,
        jobService: AiJobService(jobs),
        transcripts: TranscriptService(database),
        provider: provider,
      );

      final result = await service.generateSubtitlesForLocalFile(
        path: file.path,
        model: 'tiny',
        sourceLanguage: 'auto',
        targetLanguage: 'zh-CN',
        outputDirectory: output,
      );

      expect(result.transcriptionJob.status, AiJobStatus.succeeded);
      expect(result.translationJob?.status, AiJobStatus.succeeded);
      expect(result.translated, isTrue);
      expect(result.outputLanguage, 'zh-CN');
      expect(result.artifacts, hasLength(2));
      expect(await result.artifacts.first.file.readAsString(), contains('你好'));
      expect(
        await result.artifacts.last.file.readAsString(),
        contains('WEBVTT'),
      );
      expect(provider.translationCalls, 1);
    },
  );

  test('dispatches probe, frame sampling, and scene indexing jobs', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final file = await File(
      '${Directory.systemTemp.path}/filmly-ai-runtime-tasks.mkv',
    ).writeAsString('fixture');
    addTearDown(() async => file.delete());
    final jobs = AiJobRepository(database);
    final transcripts = TranscriptService(database);
    final service = MediaIntelligenceService(
      assets: IntelligenceAssetRepository(database),
      jobs: jobs,
      jobService: AiJobService(jobs),
      transcripts: transcripts,
      provider: FakeAiProvider(),
      sceneIndex: SceneIndexService(
        transcripts,
        ContentSegmentRepository(database),
      ),
    );
    final transcribed = await service.transcribeLocalFile(
      path: file.path,
      model: 'tiny',
      language: 'en',
    );

    final probe = await service.probeAsset(assetId: transcribed.assetId);
    final frames = await service.sampleFramesAsset(
      assetId: transcribed.assetId,
      outputDirectory: Directory.systemTemp.path,
      durationMs: 1000,
      count: 2,
    );
    final scenes = await service.indexScenesAsset(assetId: transcribed.assetId);

    expect(probe.status, AiJobStatus.succeeded);
    expect(frames.status, AiJobStatus.succeeded);
    expect(scenes.status, AiJobStatus.succeeded);
    expect(probe.checkpoint, contains('format'));
    expect(frames.checkpoint, contains('frame-0001.jpg'));
    expect(scenes.checkpoint, contains('sceneCount'));
    final sceneRows = await database.select(database.contentSegments).get();
    expect(sceneRows.single.screenshotPath, contains('frame-0001.jpg'));
  });
}

class FakeAiProvider implements AiProvider {
  String? lastPath;
  var translationCalls = 0;

  @override
  String get id => 'fake';

  @override
  Future<Map<String, dynamic>> probe(
    String path, {
    void Function(double progress)? onProgress,
  }) async => {'format': 'fixture'};

  @override
  Future<List<String>> sampleFrames({
    required String path,
    required String outputDirectory,
    required int durationMs,
    int count = 12,
    void Function(double progress)? onProgress,
  }) async => [
    '$outputDirectory/frame-0001.jpg',
    '$outputDirectory/frame-0002.jpg',
  ];

  @override
  Future<TranscriptionResult> transcribe({
    required String path,
    required String language,
    required String model,
    void Function(double progress)? onProgress,
  }) async {
    lastPath = path;
    onProgress?.call(0.5);
    return const TranscriptionResult(
      language: 'en',
      segments: [
        ProviderTranscriptSegment(startMs: 0, endMs: 1000, text: 'hello'),
      ],
    );
  }

  @override
  Future<TranslationResult> translate({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
    required String model,
    void Function(double progress)? onProgress,
  }) async {
    translationCalls++;
    onProgress?.call(1);
    return TranslationResult(
      language: targetLanguage,
      texts: texts.map((_) => '你好').toList(growable: false),
    );
  }

  @override
  Future<List<double>> embed({required String text, required String model}) =>
      Future.error(UnsupportedError('not used'));
}
