import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/services/emby/emby_service.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';

void main() {
  late HttpServer server;
  late http.Client client;
  late EmbyService emby;
  late String base;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = http.Client();
    emby = EmbyService(client);
    base = 'http://127.0.0.1:${server.port}';

    server.listen((request) async {
      final path = request.uri.path;
      if (path == '/Users/AuthenticateByName') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'AccessToken': 'tok123',
              'User': {'Id': 'user1'},
            }),
          );
      } else if (path == '/Users/user1/Items') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'Items': [
                {
                  'Id': 'm1',
                  'Name': 'Dune',
                  'Type': 'Movie',
                  'ProductionYear': 2021,
                  'ImageTags': {'Primary': 'abc'},
                },
                {
                  'Id': 's1',
                  'Name': 'Dark',
                  'Type': 'Series',
                  'ProductionYear': 2017,
                },
              ],
            }),
          );
      } else if (path == '/Shows/s1/Episodes') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'Items': [
                {
                  'Id': 'e1',
                  'Name': 'Secrets',
                  'Type': 'Episode',
                  'ParentIndexNumber': 1,
                  'IndexNumber': 1,
                },
              ],
            }),
          );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('authenticates and lists movies + series', () async {
    await emby.connect(EmbyConfig(url: base, username: 'u', password: 'p'));
    expect(emby.isConnected, isTrue);
    expect(emby.accessToken, 'tok123');

    final items = await emby.fetchLibrary();
    expect(items.length, 2);
    expect(items.first.name, 'Dune');
    expect(items.first.type, 'Movie');
    expect(items[1].type, 'Series');
  });

  test('fetches episodes for a series', () async {
    await emby.connect(EmbyConfig(url: base, username: 'u', password: 'p'));
    final eps = await emby.fetchEpisodes('s1');
    expect(eps.single.name, 'Secrets');
    expect(eps.single.seasonNumber, 1);
    expect(eps.single.episodeNumber, 1);
  });

  test('stream URL embeds the access token', () async {
    await emby.connect(EmbyConfig(url: base, username: 'u', password: 'p'));
    final url = emby.streamUrl('m1');
    expect(url, '$base/Videos/m1/stream?static=true&api_key=tok123');
  });

  test('connect throws on auth failure', () async {
    await server.close(force: true);
    expect(
      () => emby.connect(
        const EmbyConfig(url: 'http://127.0.0.1:1', username: 'u'),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('entry factory round-trips an Emby movie source', () {
    final media = MediaLibraryEntryFactory.fromEmbyMovieOrShow(
      baseUrl: 'http://emby.local',
      itemId: 'm1',
      title: 'Dune',
      year: '2021',
      isSeries: false,
    );
    expect(media.type, MediaType.movie);

    final source = MediaLibraryEntryFactory.embySourceFor(media);
    expect(source, isNotNull);
    expect(source!.baseUrl, 'http://emby.local');
    expect(source.itemId, 'm1');
  });
}
