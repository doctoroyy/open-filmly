import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/intelligence/intelligence_asset_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/intelligence_search_repository.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/media_identity_service.dart';
import 'package:open_filmly/services/intelligence/semantic_search_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test('returns a playable timestamp for transcript matches', () async {
    final core = AppDatabase(NativeDatabase.memory());
    final intelligence = IntelligenceDatabase.inMemory();
    addTearDown(core.close);
    addTearDown(intelligence.close);

    final media = const Media(
      id: 'movie-1',
      title: 'Rain Film',
      year: '2026',
      type: MediaType.movie,
      path: '/Movies/rain.mkv',
    );
    final mediaRepository = MediaRepository(core);
    await mediaRepository.upsert(media);
    final identity = MediaIdentityService.fromDescriptor(
      sourceScope: 'local',
      canonicalUri: media.path,
      fileSize: 10,
    );
    await IntelligenceAssetRepository(intelligence).upsert(
      identity: identity,
      mediaId: media.id,
    );
    await TranscriptService(intelligence).saveProviderResult(
      identity.identityKey,
      const TranscriptionResult(
        language: 'en',
        segments: [
          ProviderTranscriptSegment(startMs: 1200, endMs: 2300, text: 'rain at night'),
        ],
      ),
    );

    final service = SemanticSearchService(
      mediaRepository: mediaRepository,
      assets: IntelligenceAssetRepository(intelligence),
      transcriptSearch: IntelligenceSearchRepository(intelligence),
    );
    final results = await service.search('rain');

    final scene = results.firstWhere((result) => result.isScene);
    expect(scene.title, 'Rain Film');
    expect(scene.startMs, 1200);
    expect(scene.mediaId, 'movie-1');
  });
  test(
    'finds Chinese character phrases without whitespace tokenization',
    () async {
      final intelligence = IntelligenceDatabase.inMemory();
      addTearDown(intelligence.close);
      final transcripts = TranscriptService(intelligence);
      await transcripts.saveProviderResult(
        'asset-1',
        const TranscriptionResult(
          language: 'zh-CN',
          segments: [
            ProviderTranscriptSegment(
              startMs: 100,
              endMs: 900,
              text: '他在雨夜的长安城门等待朋友',
            ),
          ],
        ),
      );

      final hits = await IntelligenceSearchRepository(
        intelligence,
      ).search('雨夜长安');

      expect(hits, hasLength(1));
      expect(hits.single.startMs, 100);
    },
  );

  test('ranks an exact title ahead of a source-path-only match', () async {
    final core = AppDatabase(NativeDatabase.memory());
    final intelligence = IntelligenceDatabase.inMemory();
    addTearDown(core.close);
    addTearDown(intelligence.close);
    final mediaRepository = MediaRepository(core);
    await mediaRepository.upsert(
      const Media(
        id: 'wrong-metadata',
        title: 'Realengo 18',
        year: '1961',
        type: MediaType.movie,
        path: '/Downloads/唐朝诡事录/18.mkv',
        dateAdded: '2026-07-22T00:00:00.000Z',
      ),
    );
    await mediaRepository.upsert(
      const Media(
        id: 'exact-title',
        title: '唐朝诡事录',
        year: '2022',
        type: MediaType.tv,
        path: '/Downloads/唐朝诡事录',
        dateAdded: '2020-01-01T00:00:00.000Z',
      ),
    );

    final service = SemanticSearchService(
      mediaRepository: mediaRepository,
      assets: IntelligenceAssetRepository(intelligence),
      transcriptSearch: IntelligenceSearchRepository(intelligence),
    );

    final results = await service.search('唐朝诡事录');

    expect(results.first.mediaId, 'exact-title');
  });
}
