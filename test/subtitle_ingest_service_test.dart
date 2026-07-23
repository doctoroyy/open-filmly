import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/services/intelligence/subtitle_ingest_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test('parses SRT cues into transcript segments', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final transcripts = TranscriptService(database);
    final ingest = SubtitleIngestService(transcripts);

    final file = File(
      '${Directory.systemTemp.path}/filmly-ingest-test.srt',
    );
    await file.writeAsString('''
1
00:00:01,000 --> 00:00:03,500
他在雨夜的长安城门

2
00:00:04,000 --> 00:00:06,000
等待朋友
''');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    final count = await ingest.ingestFile(
      assetId: 'asset-srt',
      path: file.path,
      language: 'zh-CN',
    );
    final rows = await transcripts.getByAsset('asset-srt');

    expect(count, 2);
    expect(rows.first.startMs, 1000);
    expect(rows.first.text, contains('雨夜'));
    expect(rows.last.text, contains('等待'));
  });

  test('parses VTT timestamps without hours', () {
    final ingest = SubtitleIngestService(
      TranscriptService(IntelligenceDatabase.inMemory()),
    );
    final segments = ingest.parseVtt('''
WEBVTT

00:01.000 --> 00:02.500
hello rain
''');
    expect(segments, hasLength(1));
    expect(segments.single.startMs, 1000);
    expect(segments.single.text, 'hello rain');
  });
}
