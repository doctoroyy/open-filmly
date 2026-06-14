import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/services/metadata/tmdb_metadata_service.dart';

void main() {
  late HttpServer server;
  late http.Client client;
  late TmdbMetadataService tmdb;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = http.Client();
    tmdb = TmdbMetadataService(
      client,
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      imageBaseUrl: 'https://image.tmdb.org/t/p',
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
  });

  test('fetchEpisodeDetails parses episode metadata', () async {
    handler = (request) async {
      if (request.uri.path == '/tv/42/season/1/episode/3') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'name': '第三集',
              'overview': '本集剧情简介。',
              'still_path': '/still.jpg',
              'air_date': '2017-12-01',
              'vote_average': 8.4,
            }),
          );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    };

    final details = await tmdb.fetchEpisodeDetails(
      tvId: 42,
      seasonNumber: 1,
      episodeNumber: 3,
      apiKey: 'demo',
    );

    expect(details, isNotNull);
    expect(details!.name, '第三集');
    expect(details.overview, '本集剧情简介。');
    expect(details.stillUrl, 'https://image.tmdb.org/t/p/w500/still.jpg');
    expect(details.airDate, '2017-12-01');
    expect(details.rating, '8.4');
  });

  test('fetchEpisodeDetails returns null on failure', () async {
    final details = await tmdb.fetchEpisodeDetails(
      tvId: 999,
      seasonNumber: 9,
      episodeNumber: 9,
      apiKey: 'demo',
    );
    expect(details, isNull);
  });

  test('fetchCredits parses top-billed cast', () async {
    handler = (request) async {
      if (request.uri.path == '/movie/42/credits') {
        request.response
          ..statusCode = 200
          ..write(
            jsonEncode({
              'cast': [
                {
                  'name': '马龙·白兰度',
                  'character': '维托·柯里昂',
                  'profile_path': '/brando.jpg',
                },
                {'name': '阿尔·帕西诺', 'character': '迈克尔', 'profile_path': null},
              ],
            }),
          );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    };

    final cast = await tmdb.fetchCredits(
      tmdbId: 42,
      type: MediaType.movie,
      apiKey: 'demo',
    );

    expect(cast.length, 2);
    expect(cast.first.name, '马龙·白兰度');
    expect(cast.first.character, '维托·柯里昂');
    expect(cast.first.profileUrl, 'https://image.tmdb.org/t/p/w500/brando.jpg');
    expect(cast[1].profileUrl, isNull);
  });

  test('fetchCredits returns empty on failure', () async {
    final cast = await tmdb.fetchCredits(
      tmdbId: 999,
      type: MediaType.tv,
      apiKey: 'demo',
    );
    expect(cast, isEmpty);
  });
}
