import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/intelligence/intelligence_asset_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/services/intelligence/content_segment_service.dart';
import 'package:open_filmly/services/intelligence/library_intelligence_indexer.dart';
import 'package:open_filmly/services/intelligence/local_embedding_service.dart';
import 'package:open_filmly/services/intelligence/subtitle_ingest_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test('indexes a local media file using its subtitle sidecar', () async {
    final core = AppDatabase(NativeDatabase.memory());
    final intelligence = IntelligenceDatabase.inMemory();
    addTearDown(core.close);
    addTearDown(intelligence.close);

    final dir = await Directory.systemTemp.createTemp('filmly-index-');
    addTearDown(() async => dir.delete(recursive: true));
    final video = File('${dir.path}/Rain Night.mkv');
    await video.writeAsString('fixture');
    final srt = File('${dir.path}/Rain Night.chs.srt');
    await srt.writeAsString('''
1
00:00:01,000 --> 00:00:02,000
雨夜的长安
''');

    final mediaRepository = MediaRepository(core);
    await mediaRepository.upsert(
      Media(
        id: video.path,
        title: 'Rain Night',
        year: '2026',
        type: MediaType.movie,
        path: video.path,
        fullPath: video.path,
      ),
    );

    final transcripts = TranscriptService(intelligence);
    final indexer = LibraryIntelligenceIndexer(
      mediaRepository: mediaRepository,
      assets: IntelligenceAssetRepository(intelligence),
      transcripts: transcripts,
      ingest: SubtitleIngestService(transcripts),
      contentSegments: ContentSegmentService(intelligence, transcripts),
      embeddings: LocalEmbeddingService(intelligence, transcripts),
    );

    final progress = await indexer.indexLibrary(limit: 10);
    expect(progress.indexed, 1);
    expect(progress.withTranscripts, 1);

    final counts = await indexer.statusCounts();
    expect(counts['assetsWithTranscripts'], greaterThan(0));
  });
}
