import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';
import 'package:open_filmly/services/library/smb_library_import_service.dart';
import 'package:open_filmly/services/smb/smb_service.dart';

import 'test_support/fake_smb_service.dart';

void main() {
  late AppDatabase db;
  late MediaRepository repo;
  late FakeSmbService smb;
  late SmbLibraryImportService importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
    smb = FakeSmbService(
      initialConfig: const SmbConfig(host: 'nas', username: 'guest'),
      directories: {
        '/Media': [smbDir('/Media/Movies'), smbDir('/Media/TV')],
        '/Media/Movies': [
          smbFile('/Media/Movies/Dune.2021.1080p.mkv', size: 2048),
          smbFile('/Media/Movies/notes.txt', size: 128),
        ],
        '/Media/TV': [smbDir('/Media/TV/Breaking Bad (2008)')],
        '/Media/TV/Breaking Bad (2008)': [
          smbDir('/Media/TV/Breaking Bad (2008)/Season 01'),
        ],
        '/Media/TV/Breaking Bad (2008)/Season 01': [
          smbFile(
            '/Media/TV/Breaking Bad (2008)/Season 01/Breaking.Bad.S01E01.mkv',
            size: 4096,
          ),
        ],
      },
    );
    importer = SmbLibraryImportService(smb, repo);
  });

  tearDown(() async {
    await db.close();
  });

  test('imports SMB files recursively into the library', () async {
    final result = await importer.importFolder(smbDir('/Media'));

    expect(result.rootPath, '/Media');
    expect(result.scannedFiles, 2);
    expect(result.importedItems, 2);
    expect(result.movieCount, 1);
    expect(result.tvCount, 1);

    final movies = await repo.getByType(MediaType.movie);
    expect(movies.single.title, 'Dune');
    expect(movies.single.year, '2021');
    expect(movies.single.path, 'smb://nas/Media/Movies/Dune.2021.1080p.mkv');
    expect(
      MediaLibraryEntryFactory.smbSourceFor(movies.single)?.path,
      '/Media/Movies/Dune.2021.1080p.mkv',
    );

    final shows = await repo.getByType(MediaType.tv);
    expect(shows.single.title, 'Breaking Bad');
    expect(shows.single.year, '2008');
  });

  test('requires an active SMB connection', () async {
    await smb.disconnect();
    await expectLater(
      importer.importFolder(smbDir('/Media')),
      throwsA(isA<StateError>()),
    );
  });
}
