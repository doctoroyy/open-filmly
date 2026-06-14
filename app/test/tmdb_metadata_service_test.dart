import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/services/library/library_metadata_sync_service.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';
import 'package:open_filmly/services/metadata/tmdb_metadata_service.dart';
import 'package:open_filmly/services/metadata/intelligent_name_recognizer.dart';

void main() {
  late HttpServer server;
  late http.Client client;
  late TmdbMetadataService tmdb;
  late AppDatabase db;
  late MediaRepository repo;
  late LibraryMetadataSyncService sync;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = http.Client();
    tmdb = TmdbMetadataService(
      client,
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      imageBaseUrl: 'https://image.tmdb.org/t/p',
    );
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
    sync = LibraryMetadataSyncService(
      repo,
      tmdb,
      IntelligentNameRecognizer(http.Client()),
    );
    handler = (request) async {
      request.response.statusCode = 404;
      await request.response.close();
    };
    server.listen((request) async {
      await handler(request);
    });
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
    await db.close();
  });

  test('fetches TMDB metadata and preserves SMB source details', () async {
    handler = (request) async {
      if (request.uri.path == '/search/movie') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'results': [
                {
                  'id': 42,
                  'title': '沙丘',
                  'poster_path': '/poster.jpg',
                  'release_date': '2021-10-22',
                  'overview': 'search overview',
                },
              ],
            }),
          );
      } else if (request.uri.path == '/movie/42') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'id': 42,
              'title': '沙丘',
              'release_date': '2021-10-22',
              'overview': 'Arrakis rises.',
              'poster_path': '/poster.jpg',
              'backdrop_path': '/backdrop.jpg',
              'vote_average': 8.2,
              'genres': [
                {'name': 'Sci-Fi'},
                {'name': 'Adventure'},
              ],
            }),
          );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    };

    final media = const Media(
      id: 'smb://nas/Media/Movies/Dune.2021.mkv',
      title: 'Dune',
      year: '2021',
      type: MediaType.movie,
      path: 'smb://nas/Media/Movies/Dune.2021.mkv',
      fullPath: '/Media/Movies/Dune.2021.mkv',
      detailsJson:
          '{"source":{"kind":"smb","host":"nas","path":"/Media/Movies/Dune.2021.mkv","share":"Media"}}',
    );

    final payload = await tmdb.fetchMetadata(media, 'demo-key');

    expect(payload, isNotNull);
    expect(payload!.title, '沙丘');
    expect(payload.year, '2021');
    expect(payload.posterPath, 'https://image.tmdb.org/t/p/w500/poster.jpg');
    expect(payload.rating, '8.2');

    final details = jsonDecode(payload.detailsJson) as Map<String, dynamic>;
    expect(details['overview'], 'Arrakis rises.');
    expect(details['source']['host'], 'nas');
    expect(details['genres'], ['Sci-Fi', 'Adventure']);
  });

  test('sync service updates repository items from TMDB responses', () async {
    handler = (request) async {
      if (request.uri.path == '/search/movie') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'results': [
                {
                  'id': 7,
                  'title': '黑客帝国',
                  'poster_path': '/matrix.jpg',
                  'release_date': '1999-03-30',
                },
              ],
            }),
          );
      } else if (request.uri.path == '/movie/7') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'id': 7,
              'title': '黑客帝国',
              'release_date': '1999-03-30',
              'overview': 'Neo wakes up.',
              'poster_path': '/matrix.jpg',
              'vote_average': 8.7,
              'genres': [
                {'name': 'Sci-Fi'},
              ],
            }),
          );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    };

    await repo.upsert(
      const Media(
        id: '/movies/matrix.mkv',
        title: 'The Matrix',
        year: '1999',
        type: MediaType.movie,
        path: '/movies/matrix.mkv',
        fullPath: '/movies/matrix.mkv',
      ),
    );

    final result = await sync.enrichByIds(
      mediaIds: const ['/movies/matrix.mkv'],
      apiKey: 'demo-key',
    );
    final updated = await repo.getById('/movies/matrix.mkv');

    expect(result.requestedItems, 1);
    expect(result.updatedItems, 1);
    expect(result.failedItems, 0);
    expect(updated, isNotNull);
    expect(updated!.title, '黑客帝国');
    expect(updated.year, '1999');
    expect(updated.posterPath, 'https://image.tmdb.org/t/p/w500/matrix.jpg');
    expect(updated.rating, '8.7');
    expect(updated.overview, 'Neo wakes up.');
  });

  test('enrichment preserves a WebDAV source and stores the tmdb id', () async {
    handler = (request) async {
      if (request.uri.path == '/search/movie') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'results': [
                {'id': 11, 'title': 'Dune', 'release_date': '2021-10-22'},
              ],
            }),
          );
      } else if (request.uri.path == '/movie/11') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'id': 11,
              'title': 'Dune',
              'release_date': '2021-10-22',
              'poster_path': '/dune.jpg',
              'vote_average': 8.0,
            }),
          );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    };

    final entry = MediaLibraryEntryFactory.fromWebDavFile(
      baseUrl: 'https://dav.example.com/dav',
      relativePath: '/Movies/Dune.2021.mkv',
    );
    await repo.upsert(entry.media);

    await sync.enrichByIds(mediaIds: [entry.media.id], apiKey: 'demo-key');
    final updated = await repo.getById(entry.media.id);

    expect(updated, isNotNull);
    // The WebDAV source must survive the detailsJson rebuild during enrichment.
    final source = MediaLibraryEntryFactory.webDavSourceFor(updated!);
    expect(source, isNotNull);
    expect(source!.baseUrl, 'https://dav.example.com/dav');
    expect(source.path, '/Movies/Dune.2021.mkv');
    // And the tmdb id is now stored for episode-level lookups.
    expect(updated.tmdbId, 11);
  });
}
