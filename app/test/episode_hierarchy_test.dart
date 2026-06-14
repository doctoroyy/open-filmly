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

    testWidgets('TV detail page renders episode list', (tester) async {
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
      expect(find.text('剧集列表'), findsOneWidget);

      // Season headers
      expect(find.text('Season 1'), findsOneWidget);
      expect(find.text('Season 2'), findsOneWidget);

      // Episode titles (shown beside an "E<n>" badge in the new glass tile)
      expect(find.text('Secrets'), findsOneWidget);
      expect(find.text('Lies'), findsOneWidget);
      expect(find.text('Beginnings and Endings'), findsOneWidget);
      expect(find.text('E1'), findsWidgets);
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
