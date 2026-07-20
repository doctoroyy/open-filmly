import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/subtitle_generation_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';
import 'package:open_filmly/services/intelligence/transcript_correction_service.dart';
import 'package:open_filmly/data/intelligence/intelligence_search_repository.dart';

void main() {
  late IntelligenceDatabase database;
  late TranscriptService transcripts;

  setUp(() {
    database = IntelligenceDatabase.inMemory();
    transcripts = TranscriptService(database);
  });

  tearDown(() async => database.close());

  test(
    'stores transcript segments in timeline order and renders SRT',
    () async {
      await transcripts.saveProviderResult(
        'asset-1',
        const TranscriptionResult(
          language: 'en',
          segments: [
            ProviderTranscriptSegment(
              startMs: 1500,
              endMs: 2500,
              text: 'World',
            ),
            ProviderTranscriptSegment(startMs: 0, endMs: 1000, text: 'Hello'),
          ],
        ),
      );

      final rows = await transcripts.getByAsset('asset-1');
      expect(rows.map((row) => row.text).toList(), ['Hello', 'World']);
      expect(
        transcripts.toSrt(rows),
        contains('00:00:00,000 --> 00:00:01,000'),
      );
    },
  );

  test(
    'corrects transcript text without moving it beyond the source timeline',
    () {
      final corrected = const TranscriptCorrectionService().correct(
        const TranscriptionResult(
          language: 'en',
          segments: [
            ProviderTranscriptSegment(
              startMs: 900,
              endMs: 900,
              text: '  Wait!!!  ',
            ),
            ProviderTranscriptSegment(
              startMs: -10,
              endMs: 200,
              text: ' Hello   world ',
            ),
          ],
        ),
      );

      expect(corrected.segments.map((segment) => segment.startMs).toList(), [
        0,
        900,
      ]);
      expect(corrected.segments.map((segment) => segment.endMs).toList(), [
        200,
        901,
      ]);
      expect(corrected.segments.map((segment) => segment.text).toList(), [
        'Hello world',
        'Wait!',
      ]);
    },
  );

  test(
    'writes generated subtitles into the requested cache directory',
    () async {
      await transcripts.saveProviderResult(
        'asset-1',
        const TranscriptionResult(
          language: 'zh-CN',
          segments: [
            ProviderTranscriptSegment(startMs: 0, endMs: 1000, text: '你好'),
          ],
        ),
      );
      final directory = await Directory.systemTemp.createTemp(
        'filmly-ai-test-',
      );
      addTearDown(() async => directory.delete(recursive: true));

      final artifact = await SubtitleGenerationService(
        transcripts,
      ).writeSrt(assetId: 'asset-1', directory: directory, language: 'zh-CN');

      expect(await artifact.file.exists(), isTrue);
      expect(artifact.segmentCount, 1);
      expect(await artifact.file.readAsString(), contains('你好'));
    },
  );

  test('renders translated SRT and WebVTT artifacts', () async {
    await transcripts.saveProviderResult(
      'asset-translation',
      const TranscriptionResult(
        language: 'en',
        segments: [
          ProviderTranscriptSegment(startMs: 0, endMs: 1250, text: 'Hello.'),
        ],
      ),
    );
    await transcripts.saveTranslations(
      'asset-translation',
      const TranslationResult(language: 'zh-CN', texts: ['你好。']),
    );
    final directory = await Directory.systemTemp.createTemp('filmly-ai-vtt-');
    addTearDown(() async => directory.delete(recursive: true));

    final artifacts = await SubtitleGenerationService(transcripts)
        .writeArtifacts(
          assetId: 'asset-translation',
          directory: directory,
          language: 'zh-CN',
          translated: true,
        );

    expect(
      artifacts.map((artifact) => artifact.file.path),
      contains(contains('.srt')),
    );
    expect(
      artifacts.map((artifact) => artifact.file.path),
      contains(contains('.vtt')),
    );
    expect(await artifacts[0].file.readAsString(), contains('你好。'));
    expect(await artifacts[1].file.readAsString(), contains('WEBVTT'));
    expect(
      await artifacts[1].file.readAsString(),
      contains('00:00:00.000 --> 00:00:01.250'),
    );
  });

  test('indexes transcript text for natural-language retrieval', () async {
    await transcripts.saveProviderResult(
      'asset-1',
      const TranscriptionResult(
        language: 'en',
        segments: [
          ProviderTranscriptSegment(
            startMs: 0,
            endMs: 1000,
            text: 'rain at night',
          ),
        ],
      ),
    );

    final hits = await IntelligenceSearchRepository(database).search('rain');
    expect(hits.single.assetId, 'asset-1');
    expect(hits.single.content, 'rain at night');
  });
}
