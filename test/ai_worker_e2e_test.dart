import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/ai_job_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_asset_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/intelligence_models.dart';
import 'package:open_filmly/services/intelligence/ai_job_service.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/ai_worker_client.dart';
import 'package:open_filmly/services/intelligence/media_intelligence_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  final python = Platform.environment['FILMLY_AI_E2E_PYTHON'];
  final mediaPath = Platform.environment['FILMLY_AI_E2E_MEDIA'];
  final workerPath =
      Platform.environment['FILMLY_AI_E2E_WORKER'] ??
      '${Directory.current.path}/tool/ai_worker/main.py';
  final missing = <String>[
    if (python == null || python.isEmpty) 'FILMLY_AI_E2E_PYTHON',
    if (mediaPath == null || mediaPath.isEmpty) 'FILMLY_AI_E2E_MEDIA',
    if (!File(workerPath).existsSync()) workerPath,
  ];

  test(
    'runs the real Worker through transcription, persistence, and subtitles',
    () async {
      final database = IntelligenceDatabase.inMemory();
      addTearDown(database.close);
      final output = await Directory.systemTemp.createTemp(
        'open-filmly-ai-e2e-artifacts-',
      );
      addTearDown(() => output.delete(recursive: true));

      final transport = await ProcessWorkerTransport.start(
        python!,
        arguments: [workerPath],
      );
      final client = AiWorkerClient(transport);
      addTearDown(client.close);

      final jobs = AiJobRepository(database);
      final service = MediaIntelligenceService(
        assets: IntelligenceAssetRepository(database),
        jobs: jobs,
        jobService: AiJobService(jobs),
        transcripts: TranscriptService(database),
        provider: LocalWorkerProvider(client),
      );

      final probe = await LocalWorkerProvider(client).probe(mediaPath!);
      expect(probe['format'], isA<Map>());

      final result = await service.generateSubtitlesForLocalFile(
        path: mediaPath,
        model: 'tiny',
        sourceLanguage: 'auto',
        targetLanguage: '',
        outputDirectory: output,
      );

      expect(result.transcriptionJob.status, AiJobStatus.succeeded);
      expect(result.transcriptionJob.progress, 1);
      expect(result.artifacts, hasLength(2));

      final segments = await TranscriptService(
        database,
      ).getByAsset(result.identity.identityKey);
      expect(segments, isNotEmpty);
      for (var i = 1; i < segments.length; i++) {
        expect(
          segments[i].startMs,
          greaterThanOrEqualTo(segments[i - 1].startMs),
        );
        expect(segments[i].endMs, greaterThan(segments[i].startMs));
      }

      final srt = await result.artifacts[0].file.readAsString();
      final vtt = await result.artifacts[1].file.readAsString();
      expect(srt, contains('subtitle'));
      expect(vtt, startsWith('WEBVTT'));
      expect(result.artifacts[0].segmentCount, segments.length);
      expect(result.artifacts[1].segmentCount, segments.length);
    },
    skip: missing.isEmpty
        ? null
        : 'Set FILMLY_AI_E2E_PYTHON and FILMLY_AI_E2E_MEDIA to run: '
              '${missing.join(', ')}',
  );
}
