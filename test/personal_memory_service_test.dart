import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/intelligence/intelligence_asset_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/watch_event_repository.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/services/intelligence/media_identity_service.dart';
import 'package:open_filmly/services/intelligence/personal_memory_service.dart';

void main() {
  test('builds local viewing memory and supports export and clear', () async {
    final core = AppDatabase(NativeDatabase.memory());
    final intelligence = IntelligenceDatabase.inMemory();
    addTearDown(core.close);
    addTearDown(intelligence.close);

    final media = const Media(
      id: 'memory-movie',
      title: 'Rain Film',
      year: '2026',
      type: MediaType.movie,
      path: '/Movies/rain.mkv',
      detailsJson: '{"genres":["Drama","Mystery"]}',
    );
    final mediaRepository = MediaRepository(core);
    await mediaRepository.upsert(media);
    final identity = MediaIdentityService.fromDescriptor(
      sourceScope: 'local',
      canonicalUri: media.path,
      fileSize: 10,
    );
    await IntelligenceAssetRepository(
      intelligence,
    ).upsert(identity: identity, mediaId: media.id);

    final service = PersonalMemoryService(
      events: WatchEventRepository(intelligence),
      assets: IntelligenceAssetRepository(intelligence),
      mediaRepository: mediaRepository,
    );
    await service.record(
      assetId: identity.identityKey,
      kind: WatchEventKind.play,
      positionMs: 0,
    );
    await service.record(
      assetId: identity.identityKey,
      kind: WatchEventKind.play,
      positionMs: 1000,
    );
    await service.record(
      assetId: identity.identityKey,
      kind: WatchEventKind.completed,
      positionMs: 10000,
    );

    final summary = await service.summary();
    expect(summary.watchedAssets, 1);
    expect(summary.completedAssets, 1);
    expect(summary.repeatAssets, 1);
    expect(summary.topicCounts['Drama'], 1);
    expect(summary.recent, isNotEmpty);
    expect(await service.exportJson(), contains(identity.identityKey));

    await service.clear();
    expect((await service.summary()).totalEvents, 0);
  });
}
