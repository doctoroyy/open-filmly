import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/services/data/database_transfer_service.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('merges media, episodes, config, and preserves target rows', () async {
    await source
        .into(source.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'mac-show',
            title: '唐朝诡事录',
            type: 'tv',
            path: '唐朝诡事录',
            dateAdded: '2026-01-01',
            lastUpdated: '2026-01-02',
            isFavorite: const Value(true),
          ),
        );
    await source
        .into(source.episodes)
        .insert(
          EpisodesCompanion.insert(
            id: 'mac-episode-01',
            showId: 'mac-show',
            seasonNumber: 1,
            episodeNumber: 1,
            path: '01.mkv',
            fullPath: const Value('/nas/唐朝诡事录/01.mkv'),
            dateAdded: '2026-01-01',
          ),
        );
    await source
        .into(source.configEntries)
        .insert(
          ConfigEntriesCompanion.insert(
            key: 'app_config',
            value: '{"smbHost":"nas"}',
          ),
        );

    await target
        .into(target.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'iphone-only',
            title: 'iPhone 本地媒体',
            type: 'movie',
            path: 'local.mp4',
            dateAdded: '2026-02-01',
            lastUpdated: '2026-02-01',
          ),
        );

    final result = await DatabaseTransferService(target).mergeFrom(source);

    expect(result.mediaRows, 1);
    expect(result.episodeRows, 1);
    expect(result.configRows, 1);
    expect(await target.select(target.mediaItems).get(), hasLength(2));
    expect(await target.select(target.episodes).get(), hasLength(1));
    expect(
      (await target.select(target.configEntries).getSingle()).value,
      '{"smbHost":"nas"}',
    );
  });

  test('keeps the newer local playback progress', () async {
    await target
        .into(target.configEntries)
        .insert(
          ConfigEntriesCompanion.insert(
            key: 'playback_progress:movie-1',
            value: '{"updatedAt":"2026-02-02T00:00:00.000Z","position":20}',
          ),
        );
    await source
        .into(source.configEntries)
        .insert(
          ConfigEntriesCompanion.insert(
            key: 'playback_progress:movie-1',
            value: '{"updatedAt":"2026-02-01T00:00:00.000Z","position":10}',
          ),
        );

    await DatabaseTransferService(target).mergeFrom(source);

    expect(
      (await target.select(target.configEntries).getSingle()).value,
      contains('"position":20'),
    );
  });
}
