import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/ai_job_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_asset_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/intelligence_models.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/ai_job_service.dart';
import 'package:open_filmly/services/intelligence/media_intelligence_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
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
  }) async => {};

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
