import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/core/router/app_router.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/episode.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/episode_repository.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/providers/data_providers.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';
import 'package:open_filmly/services/smb/smb_service.dart';
import 'package:smb_connect/smb_connect.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late EpisodeRepository episodeRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mediaRepo = MediaRepository(db);
    episodeRepo = EpisodeRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MediaLibraryEntryFactory episode parsing', () {
    test('extracts season and episode from S01E03 pattern', () {
      final entry = MediaLibraryEntryFactory.fromLocalPath(
        '/tv/Breaking Bad/Season 1/Breaking.Bad.S01E03.1080p.mkv',
      );

      expect(entry.media.type, MediaType.tv);
      expect(entry.media.title, 'Breaking Bad');
      expect(entry.hasEpisode, isTrue);
      expect(entry.episode!.seasonNumber, 1);
      expect(entry.episode!.episodeNumber, 3);
    });

    test('extracts from uppercase S02E10', () {
      final entry = MediaLibraryEntryFactory.fromLocalPath(
        '/shows/The Office/Season 2/The.Office.S02E10.Christmas.Party.mkv',
      );

      expect(entry.media.type, MediaType.tv);
      expect(entry.hasEpisode, isTrue);
      expect(entry.episode!.seasonNumber, 2);
      expect(entry.episode!.episodeNumber, 10);
    });

    test('movie files do not produce episodes', () {
      final entry = MediaLibraryEntryFactory.fromLocalPath(
        '/movies/Inception.2010.1080p.BluRay.mkv',
      );

      expect(entry.media.type, MediaType.movie);
      expect(entry.hasEpisode, isFalse);
    });

    test('multiple episodes from same show share a show ID', () {
      final entry1 = MediaLibraryEntryFactory.fromLocalPath(
        '/tv/Dark/Season 1/Dark.S01E01.mkv',
      );
      final entry2 = MediaLibraryEntryFactory.fromLocalPath(
        '/tv/Dark/Season 1/Dark.S01E02.mkv',
      );

      expect(entry1.media.id, entry2.media.id);
      expect(entry1.episode!.id, isNot(entry2.episode!.id));
    });

    test(
      'separate season folders with different years still share show ID',
      () {
        final first = MediaLibraryEntryFactory.fromLocalPath(
          '/library/The Expanse 第一季 (2015)/The.Expanse.S01E01.mkv',
        );
        final second = MediaLibraryEntryFactory.fromLocalPath(
          '/archive/The Expanse 第二季 (2017)/The.Expanse.S02E01.mkv',
        );

        expect(first.media.title, 'The Expanse');
        expect(second.media.title, 'The Expanse');
        expect(first.media.id, second.media.id);
      },
    );

    test('SMB and WebDAV group seasons by source and show title', () {
      final smbFirst = MediaLibraryEntryFactory.fromSmbFile(
        config: const SmbConfig(host: 'nas'),
        file: SmbFile(
          '/TV/Dark 第一季/Dark.S01E01.mkv',
          r'\\nas\TV\Dark 第一季\Dark.S01E01.mkv',
          'TV',
          0,
          0,
          0,
          0x20,
          1,
          true,
        ),
      );
      final smbSecond = MediaLibraryEntryFactory.fromSmbFile(
        config: const SmbConfig(host: 'nas'),
        file: SmbFile(
          '/Archive/Dark 第二季/Dark.S02E01.mkv',
          r'\\nas\Archive\Dark 第二季\Dark.S02E01.mkv',
          'TV',
          0,
          0,
          0,
          0x20,
          1,
          true,
        ),
      );
      final davFirst = MediaLibraryEntryFactory.fromWebDavFile(
        baseUrl: 'https://dav.example.com',
        relativePath: '/TV/Dark 第一季/Dark.S01E01.mkv',
      );
      final davSecond = MediaLibraryEntryFactory.fromWebDavFile(
        baseUrl: 'https://dav.example.com',
        relativePath: '/Archive/Dark 第二季/Dark.S02E01.mkv',
      );

      expect(smbFirst.media.id, smbSecond.media.id);
      expect(davFirst.media.id, davSecond.media.id);
      expect(smbFirst.media.id, isNot(davFirst.media.id));
    });
  });

  group('EpisodeRepository', () {
    test('upserts and retrieves episodes grouped by season', () async {
      const showId = 'tv:breaking-bad';

      await mediaRepo.upsert(
        const Media(
          id: 'tv:breaking-bad',
          title: 'Breaking Bad',
          year: '2008',
          type: MediaType.tv,
          path: '/tv/Breaking Bad',
        ),
      );

      final episodes = [
        const Episode(
          id: 'ep-s01e01',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 1,
          title: 'Pilot',
          path: '/tv/Breaking Bad/Season 1/S01E01.mkv',
        ),
        const Episode(
          id: 'ep-s01e02',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 2,
          title: "Cat's in the Bag",
          path: '/tv/Breaking Bad/Season 1/S01E02.mkv',
        ),
        const Episode(
          id: 'ep-s02e01',
          showId: showId,
          seasonNumber: 2,
          episodeNumber: 1,
          title: 'Seven Thirty-Seven',
          path: '/tv/Breaking Bad/Season 2/S02E01.mkv',
        ),
      ];

      await episodeRepo.upsertAll(episodes);

      final seasons = await episodeRepo.getByShowGrouped(showId);
      expect(seasons.length, 2);
      expect(seasons[0].number, 1);
      expect(seasons[0].episodes.length, 2);
      expect(seasons[1].number, 2);
      expect(seasons[1].episodes.length, 1);
    });

    test('countByShow returns total episode count', () async {
      const showId = 'tv:test-show';
      await mediaRepo.upsert(
        const Media(
          id: showId,
          title: 'Test Show',
          year: '2020',
          type: MediaType.tv,
          path: '/tv/Test Show',
        ),
      );

      await episodeRepo.upsertAll([
        const Episode(
          id: 'a',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 1,
          path: '/a.mkv',
        ),
        const Episode(
          id: 'b',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 2,
          path: '/b.mkv',
        ),
        const Episode(
          id: 'c',
          showId: showId,
          seasonNumber: 2,
          episodeNumber: 1,
          path: '/c.mkv',
        ),
      ]);

      final count = await episodeRepo.countByShow(showId);
      expect(count, 3);
    });

    test('deduplicates season episodes and prefers a playable video', () async {
      const showId = 'tv:duplicate-show';
      await mediaRepo.upsert(
        const Media(
          id: showId,
          title: 'Duplicate Show',
          year: '2024',
          type: MediaType.tv,
          path: '/tv/Duplicate Show',
        ),
      );

      await episodeRepo.upsertAll([
        const Episode(
          id: 'generated-s1e1',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 1,
          title: 'Stale metadata',
          path: '/tv/Duplicate Show',
        ),
        const Episode(
          id: 'apple-double-s1e1',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 1,
          title: 'AppleDouble',
          path: '/tv/Duplicate Show/._Show.S01E01.mkv',
        ),
        const Episode(
          id: 'video-s1e1',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 1,
          title: 'Pilot',
          path: '/tv/Duplicate Show/Show.S01E01.mkv',
          fullPath: '/tv/Duplicate Show/Show.S01E01.mkv',
        ),
      ]);

      final episodes = await episodeRepo.getByShow(showId);
      expect(episodes, hasLength(1));
      expect(episodes.single.id, 'video-s1e1');
      expect(await episodeRepo.countByShow(showId), 1);
    });
  });

  group('TV detail page shows episodes', () {
    Future<void> pumpApp(
      WidgetTester tester, {
      String initialLocation = '/',
    }) async {
      final router = createAppRouter(initialLocation: initialLocation);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('TV detail page switches seasons with tabs', (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const showId = 'tv:dark';
      await mediaRepo.upsert(
        const Media(
          id: showId,
          title: 'Dark',
          year: '2017',
          type: MediaType.tv,
          path: '/tv/Dark',
        ),
      );
      await episodeRepo.upsertAll([
        const Episode(
          id: 'dark-s01e01',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 1,
          title: 'Secrets',
          path: '/tv/Dark/Season 1/S01E01.mkv',
        ),
        const Episode(
          id: 'dark-s01e02',
          showId: showId,
          seasonNumber: 1,
          episodeNumber: 2,
          title: 'Lies',
          path: '/tv/Dark/Season 1/S01E02.mkv',
        ),
        const Episode(
          id: 'dark-s02e01',
          showId: showId,
          seasonNumber: 2,
          episodeNumber: 1,
          title: 'Beginnings and Endings',
          path: '/tv/Dark/Season 2/S02E01.mkv',
        ),
      ]);

      await pumpApp(tester, initialLocation: mediaDetailLocation('tv:dark'));
      await tester.pumpAndSettle();

      // Show info is displayed
      expect(find.text('Dark'), findsWidgets);

      // Seasons are horizontal tabs; only the selected season is rendered.
      expect(find.text('第1季'), findsOneWidget);
      expect(find.text('第2季'), findsOneWidget);
      expect(find.textContaining('Secrets'), findsOneWidget);
      expect(find.textContaining('Lies'), findsOneWidget);
      expect(find.textContaining('Beginnings and Endings'), findsNothing);
      expect(find.byKey(const Key('episode_card_dark-s01e01')), findsOneWidget);

      await tester.tap(find.byKey(const Key('season_tab_2')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Secrets'), findsNothing);
      expect(find.textContaining('Lies'), findsNothing);
      expect(find.textContaining('Beginnings and Endings'), findsOneWidget);
      expect(find.byKey(const Key('episode_card_dark-s02e01')), findsOneWidget);
    });

    testWidgets('TV detail shows empty state when no episodes', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mediaRepo.upsert(
        const Media(
          id: 'tv:empty-show',
          title: 'Empty Show',
          year: '2023',
          type: MediaType.tv,
          path: '/tv/Empty Show',
        ),
      );

      await pumpApp(
        tester,
        initialLocation: mediaDetailLocation('tv:empty-show'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('暂无剧集数据'), findsOneWidget);
    });
  });
}
