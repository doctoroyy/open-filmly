import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/app_config.dart';
import 'package:open_filmly/data/models/episode.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/episode_repository.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/services/library/library_auto_scan_service.dart';
import 'package:open_filmly/services/library/library_metadata_sync_service.dart';
import 'package:open_filmly/services/library/library_scanner_service.dart';
import 'package:open_filmly/services/metadata/intelligent_name_recognizer.dart';
import 'package:open_filmly/services/metadata/tmdb_metadata_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

void main() {
  late AppDatabase db;
  late MediaRepository repo;
  late EpisodeRepository episodeRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
    episodeRepo = EpisodeRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MediaRepository.deleteAll', () {
    test('clears media even when episodes reference them', () async {
      // A TV show with an episode pointing at it via foreign key.
      await repo.upsert(
        const Media(
          id: 'show-1',
          title: 'Stranger Things',
          year: '2016',
          type: MediaType.tv,
          path: '/tv/stranger',
        ),
      );
      await episodeRepo.upsert(
        const Episode(
          id: 'ep-1',
          showId: 'show-1',
          seasonNumber: 1,
          episodeNumber: 1,
          path: '/tv/stranger/s01e01.mkv',
        ),
      );

      // Must not throw a foreign key constraint error.
      await repo.deleteAll();

      expect(await repo.getByType(MediaType.tv), isEmpty);
      expect(await episodeRepo.getByShow('show-1'), isEmpty);
    });
  });

  group('LibraryAutoScanService', () {
    late Directory tempDir;
    late LibraryScannerService scanner;

    setUp(() async {
      scanner = LibraryScannerService(repo, episodeRepo);
      tempDir = await Directory.systemTemp.createTemp('open_filmly_autoscan');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> createFile(String relativePath) async {
      final file = File(path.join(tempDir.path, relativePath));
      await file.create(recursive: true);
      await file.writeAsBytes(const [0x00]);
    }

    LibraryAutoScanService buildService() {
      final dummyClient = http.Client();
      final metadataSync = LibraryMetadataSyncService(
        repo,
        TmdbMetadataService(dummyClient),
        IntelligentNameRecognizer(dummyClient),
      );
      return LibraryAutoScanService(scanner, metadataSync, repo, episodeRepo);
    }

    test('skips when autoScanOnStartup is disabled', () async {
      await createFile('Movies/The.Matrix.1999.mkv');
      final service = buildService();

      final result = await service.run(
        AppConfig(
          selectedFolders: [path.join(tempDir.path, 'Movies')],
          autoScanOnStartup: false,
        ),
      );

      expect(result.skipped, isTrue);
      expect(result.importedItems, 0);
      expect(await repo.getByType(MediaType.movie), isEmpty);
    });

    test('retitles dirty legacy entries even when scan is skipped', () async {
      // Legacy SMB-imported entry with a dirty release-name title.
      await repo.upsert(
        const Media(
          id: 'smb://nas/m/drishyam',
          title: 'Drishyam 10bit MNHD FRDS',
          year: '2015',
          type: MediaType.movie,
          path: 'smb://nas/m/drishyam',
          fullPath: '/m/Drishyam.2015.1080p.10bit.MNHD.FRDS.mkv',
        ),
      );
      // Enriched entry: TMDB title must NOT be touched.
      await repo.upsert(
        const Media(
          id: 'enriched',
          title: '黑客帝国',
          year: '1999',
          type: MediaType.movie,
          path: '/m/matrix.mkv',
          fullPath: '/m/The.Matrix.1999.1080p.mkv',
          detailsJson: '{"tmdbId": 603}',
        ),
      );

      final service = buildService();
      final result = await service.run(const AppConfig());

      expect(result.skipped, isTrue);
      expect(result.retitledItems, 1);
      expect(result.hasChanges, isTrue);

      final fixed = await repo.getById('smb://nas/m/drishyam');
      expect(fixed!.title, 'Drishyam');
      final untouched = await repo.getById('enriched');
      expect(untouched!.title, '黑客帝国');
    });

    test('skips when no folders are configured', () async {
      final service = buildService();
      final result = await service.run(const AppConfig());
      expect(result.skipped, isTrue);
    });

    test(
      'repairs numeric episode rows and purges AppleDouble sidecars',
      () async {
        const showId = 'smb://nas/tv/唐朝诡事录.4K.内封/22.mkv';
        await repo.upsert(
          const Media(
            id: showId,
            title: '唐朝诡事录',
            year: '2022',
            type: MediaType.tv,
            path: showId,
            fullPath: '/tv/唐朝诡事录.4K.内封',
            detailsJson: '{"tmdbId":211089}',
          ),
        );
        await episodeRepo.upsertAll([
          const Episode(
            id: 'ep-09',
            showId: showId,
            seasonNumber: 1,
            episodeNumber: 1,
            path: 'smb://nas/tv/唐朝诡事录.4K.内封/09.mkv',
            fullPath: '/tv/唐朝诡事录.4K.内封/09.mkv',
          ),
          const Episode(
            id: 'ep-22',
            showId: showId,
            seasonNumber: 1,
            episodeNumber: 1,
            path: 'smb://nas/tv/唐朝诡事录.4K.内封/22.mkv',
            fullPath: '/tv/唐朝诡事录.4K.内封/22.mkv',
          ),
          const Episode(
            id: 'sidecar',
            showId: showId,
            seasonNumber: 1,
            episodeNumber: 9,
            path: '/tv/唐朝诡事录.4K.内封/._09.mkv',
            fullPath: '/tv/唐朝诡事录.4K.内封/._09.mkv',
          ),
        ]);

        final result = await buildService().run(const AppConfig());
        final episodes = await episodeRepo.getByShow(showId);

        expect(result.hasChanges, isTrue);
        expect(episodes.map((episode) => episode.episodeNumber), [9, 22]);
        expect(
          episodes.every((episode) => !episode.path.contains('._')),
          isTrue,
        );
      },
    );

    test(
      'removes exact duplicate episode rows without removing alternatives',
      () async {
        const showId = 'tv:duplicate-episode-paths';
        await repo.upsert(
          const Media(
            id: showId,
            title: '测试剧集',
            year: '2022',
            type: MediaType.tv,
            path: '/tv/test',
          ),
        );
        await episodeRepo.upsertAll([
          const Episode(
            id: 'same-file-old',
            showId: showId,
            seasonNumber: 1,
            episodeNumber: 1,
            path: '/tv/test/S01E01.mkv',
            fullPath: '/tv/test/S01E01.mkv',
          ),
          const Episode(
            id: 'same-file-new',
            showId: showId,
            seasonNumber: 1,
            episodeNumber: 1,
            path: '/tv/test/S01E01.mkv',
            fullPath: '/tv/test/S01E01.mkv',
          ),
          const Episode(
            id: 'alternative-file',
            showId: showId,
            seasonNumber: 1,
            episodeNumber: 1,
            path: 'smb://nas/tv/test/S01E01.mkv',
            fullPath: '/tv/test/S01E01.mkv',
          ),
        ]);

        await buildService().run(const AppConfig());
        final raw = await episodeRepo.getRawByShow(showId);
        expect(raw, hasLength(2));
        expect(raw.map((episode) => episode.id), contains('alternative-file'));
      },
    );

    test('imports new files without clearing the existing library', () async {
      // Pre-existing item that the incremental scan must preserve.
      await repo.upsert(
        const Media(
          id: 'manual-1',
          title: 'Manually Added',
          year: '2000',
          type: MediaType.movie,
          path: '/elsewhere/manual.mkv',
        ),
      );

      await createFile('Movies/Inception.2010.mkv');
      final service = buildService();

      final result = await service.run(
        AppConfig(selectedFolders: [path.join(tempDir.path, 'Movies')]),
      );

      expect(result.skipped, isFalse);
      expect(result.scannedFiles, 1);
      expect(result.importedItems, 1);

      final movies = await repo.getByType(MediaType.movie);
      // Both the manual item and the freshly scanned one survive.
      expect(movies.length, 2);
      expect(movies.map((m) => m.title), contains('Manually Added'));
      expect(movies.map((m) => m.title), contains('Inception'));
    });
  });
}
