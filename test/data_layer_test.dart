import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/app_config.dart';
import 'package:open_filmly/data/models/library_shelf.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/models/media_library_query.dart';
import 'package:open_filmly/data/models/playback_progress.dart';
import 'package:open_filmly/data/repositories/config_repository.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/data/repositories/playback_progress_repository.dart';

/// Data-layer tests against an in-memory drift database. This is the
/// automatable form of the M3 "config persists" milestone check, plus media
/// CRUD, details-JSON parsing, and legacy-config import.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('ConfigRepository', () {
    test('returns defaults when empty', () async {
      final config = await ConfigRepository(db).load();
      expect(config.smbHost, '');
      expect(config.smbUsername, 'guest');
    });

    test('round-trips a saved config', () async {
      final repo = ConfigRepository(db);
      await repo.save(
        const AppConfig(
          smbHost: '192.168.1.50',
          smbUsername: 'admin',
          smbPassword: 'secret',
          smbShare: 'media',
          tmdbApiKey: 'tmdb-key',
          selectedFolders: ['/media/movies', '/media/tv'],
        ),
      );
      final loaded = await repo.load();
      expect(loaded.smbHost, '192.168.1.50');
      expect(loaded.smbUsername, 'admin');
      expect(loaded.smbPassword, 'secret');
      expect(loaded.smbShare, 'media');
      expect(loaded.tmdbApiKey, 'tmdb-key');
      expect(loaded.selectedFolders, ['/media/movies', '/media/tv']);
    });

    test('imports Electron-era field aliases', () {
      final legacy = AppConfig.fromJson({
        'host': '10.0.0.2',
        'username': 'nas',
        'sharePath': 'share1',
        'tmdbApi': 'legacy-tmdb',
      });
      expect(legacy.smbHost, '10.0.0.2');
      expect(legacy.smbUsername, 'nas');
      expect(legacy.smbShare, 'share1');
      expect(legacy.tmdbApiKey, 'legacy-tmdb');
    });
  });

  group('MediaRepository', () {
    test('upsert + getByType + getById + counts', () async {
      final repo = MediaRepository(db);
      await repo.upsert(
        const Media(
          id: 'm1',
          title: 'The Matrix',
          year: '1999',
          type: MediaType.movie,
          path: '/movies/matrix.mkv',
          dateAdded: '2024-01-01T00:00:00.000',
        ),
      );
      await repo.upsert(
        const Media(
          id: 't1',
          title: 'Breaking Bad',
          year: '2008',
          type: MediaType.tv,
          path: '/tv/bb',
          dateAdded: '2024-01-01T00:00:00.000',
        ),
      );

      final movies = await repo.getByType(MediaType.movie);
      expect(movies.length, 1);
      expect(movies.first.title, 'The Matrix');

      final byId = await repo.getById('t1');
      expect(byId, isNotNull);
      expect(byId!.type, MediaType.tv);

      final counts = await repo.countByType();
      final shelfCounts = await repo.countByShelf();
      // Shelf counts are exclusive and only include TMDB-matched movie/tv.
      expect(
        shelfCounts.values.fold<int>(0, (a, b) => a + b),
        counts.values.fold<int>(0, (a, b) => a + b),
      );
      expect(shelfCounts[LibraryShelf.movie], 0);
      expect(shelfCounts[LibraryShelf.tv], 0);
      expect(shelfCounts[LibraryShelf.other], 2);
      expect(counts[MediaType.movie], 1);
      expect(counts[MediaType.tv], 1);
      expect(counts[MediaType.unknown], 0);
    });

    test('countByShelf keeps matched and unmatched media exclusive', () async {
      final repo = MediaRepository(db);
      await repo.upsert(
        const Media(
          id: 'matched-movie',
          title: 'The Matrix',
          year: '1999',
          type: MediaType.movie,
          path: '/movies/matrix.mkv',
          detailsJson: '{"tmdbId":603}',
        ),
      );
      await repo.upsert(
        const Media(
          id: 'unmatched-movie',
          title: '课程视频',
          year: '2026',
          type: MediaType.movie,
          path: '/courses/css3.mkv',
        ),
      );
      await repo.upsert(
        const Media(
          id: 'matched-tv',
          title: 'Breaking Bad',
          year: '2008',
          type: MediaType.tv,
          path: '/tv/breaking-bad',
          detailsJson: '{"tmdbId":1396}',
        ),
      );
      await repo.upsert(
        const Media(
          id: 'anime',
          title: '动漫文件',
          year: '2026',
          type: MediaType.movie,
          path: '/media/动漫/show.mkv',
        ),
      );

      final counts = await repo.countByShelf();

      expect(counts[LibraryShelf.movie], 1);
      expect(counts[LibraryShelf.tv], 1);
      expect(counts[LibraryShelf.anime], 1);
      expect(counts[LibraryShelf.other], 1);
    });

    test('upsert updates an existing row in place', () async {
      final repo = MediaRepository(db);
      await repo.upsert(
        const Media(
          id: 'm1',
          title: 'Old Title',
          year: '1999',
          type: MediaType.movie,
          path: '/movies/x.mkv',
        ),
      );
      await repo.upsert(
        const Media(
          id: 'm1',
          title: 'New Title',
          year: '1999',
          type: MediaType.movie,
          path: '/movies/x.mkv',
        ),
      );
      final movies = await repo.getByType(MediaType.movie);
      expect(movies.length, 1);
      expect(movies.first.title, 'New Title');
    });

    test('parses details JSON into enhancement fields', () async {
      final repo = MediaRepository(db);
      await repo.upsert(
        const Media(
          id: 'm2',
          title: 'Dune',
          year: '2021',
          type: MediaType.movie,
          path: '/movies/dune.mkv',
          detailsJson:
              '{"overview":"Sci-fi epic","release_date":"2021-10-22",'
              '"genres":[{"name":"Sci-Fi"},{"name":"Adventure"}]}',
        ),
      );
      final movie = await repo.getById('m2');
      expect(movie!.overview, 'Sci-fi epic');
      expect(movie.releaseDate, '2021-10-22');
      expect(movie.genres, ['Sci-Fi', 'Adventure']);
    });

    test('browse filters search terms and sorts by rating/year', () async {
      final repo = MediaRepository(db);
      await repo.upsert(
        const Media(
          id: 'm1',
          title: 'The Matrix',
          year: '1999',
          type: MediaType.movie,
          path: '/movies/matrix.mkv',
          rating: '8.7',
          detailsJson: '{"overview":"Neo enters the matrix"}',
        ),
      );
      await repo.upsert(
        const Media(
          id: 'm2',
          title: 'Dune',
          year: '2021',
          type: MediaType.movie,
          path: '/movies/dune.mkv',
          rating: '8.0',
          detailsJson: '{"overview":"Desert prophecy"}',
        ),
      );
      await repo.upsert(
        const Media(
          id: 't1',
          title: 'Dark',
          year: '2017',
          type: MediaType.tv,
          path: '/tv/dark',
          rating: '8.8',
          detailsJson: '{"overview":"Time travel mystery"}',
        ),
      );

      final searched = await repo.browse(
        type: MediaType.movie,
        searchTerm: 'neo 1999',
      );
      expect(searched.map((item) => item.id), ['m1']);

      final byRating = await repo.browse(sort: MediaSort.rating);
      expect(byRating.map((item) => item.id).take(2), ['t1', 'm1']);

      final byYear = await repo.browse(
        type: MediaType.movie,
        sort: MediaSort.year,
      );
      expect(byYear.map((item) => item.id), ['m2', 'm1']);
    });
  });

  group('PlaybackProgressRepository', () {
    test('stores resume points and filters continue-watching items', () async {
      final repo = PlaybackProgressRepository(db);
      await repo.save(
        PlaybackProgress(
          mediaId: 'm1',
          position: const Duration(minutes: 12),
          duration: const Duration(minutes: 50),
          updatedAt: DateTime.parse('2026-06-01T12:00:00.000Z'),
        ),
      );
      await repo.save(
        PlaybackProgress(
          mediaId: 'm2',
          position: const Duration(minutes: 40),
          duration: const Duration(minutes: 42),
          updatedAt: DateTime.parse('2026-06-01T12:05:00.000Z'),
          completed: true,
        ),
      );

      final saved = await repo.getByMediaId('m1');
      expect(saved, isNotNull);
      expect(saved!.hasResumePoint, isTrue);
      expect(saved.progressLabel, '12:00 / 50:00');

      final items = await repo.getContinueWatching();
      expect(items.map((item) => item.mediaId), ['m1']);
    });

    test(
      'capture ignores short sessions and marks near-end playback complete',
      () {
        final short = PlaybackProgress.capture(
          mediaId: 'm1',
          position: const Duration(seconds: 3),
          duration: const Duration(minutes: 20),
        );
        expect(short, isNull);

        final nearEnd = PlaybackProgress.capture(
          mediaId: 'm2',
          position: const Duration(minutes: 57),
          duration: const Duration(minutes: 60),
        );
        expect(nearEnd, isNotNull);
        expect(nearEnd!.completed, isTrue);
        expect(nearEnd.position, const Duration(minutes: 60));
      },
    );
  });
}
