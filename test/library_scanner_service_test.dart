import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/services/library/library_scanner_service.dart';
import 'package:path/path.dart' as path;

void main() {
  late AppDatabase db;
  late MediaRepository repo;
  late LibraryScannerService scanner;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
    scanner = LibraryScannerService(repo);
    tempDir = await Directory.systemTemp.createTemp('open_filmly_scan_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await db.close();
  });

  Future<void> createFile(String relativePath) async {
    final file = File(path.join(tempDir.path, relativePath));
    await file.create(recursive: true);
    await file.writeAsBytes(const [0x00]);
  }

  test('imports local movie and tv files into the library', () async {
    await createFile('Movies/The.Matrix.1999.1080p.mkv');
    await createFile(
      'TV/Breaking Bad (2008)/Season 01/Breaking.Bad.S01E01.mkv',
    );
    await createFile('Movies/readme.txt');

    final result = await scanner.scanFolders([
      path.join(tempDir.path, 'Movies'),
      path.join(tempDir.path, 'TV'),
    ]);

    expect(result.scannedFiles, 2);
    expect(result.importedItems, 2);
    expect(result.movieCount, 1);
    expect(result.tvCount, 1);
    expect(result.missingFolders, 0);

    final movies = await repo.getByType(MediaType.movie);
    expect(movies.single.title, 'The Matrix');
    expect(movies.single.year, '1999');
    expect(movies.single.fullPath, contains('The.Matrix.1999.1080p.mkv'));

    final shows = await repo.getByType(MediaType.tv);
    expect(shows.single.title, 'Breaking Bad');
    expect(shows.single.year, '2008');
  });

  test('skips missing folders and non-video files', () async {
    await createFile('Docs/readme.txt');

    final result = await scanner.scanFolders([
      path.join(tempDir.path, 'Missing'),
      path.join(tempDir.path, 'Docs'),
    ]);

    expect(result.scannedFiles, 0);
    expect(result.importedItems, 0);
    expect(result.movieCount, 0);
    expect(result.tvCount, 0);
    expect(result.missingFolders, 1);
  });
}
