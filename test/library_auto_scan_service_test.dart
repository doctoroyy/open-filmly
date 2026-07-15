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
      return LibraryAutoScanService(scanner, metadataSync, repo);
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
