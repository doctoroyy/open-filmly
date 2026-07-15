import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/episode.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/data/repositories/episode_repository.dart';
import 'package:open_filmly/services/library/library_metadata_sync_service.dart';
import 'package:open_filmly/services/metadata/tmdb_metadata_service.dart';
import 'package:open_filmly/services/metadata/intelligent_name_recognizer.dart';

void main() {
  late HttpServer server;
  late http.Client client;
  late TmdbMetadataService tmdb;
  late AppDatabase db;
  late MediaRepository repo;
  late EpisodeRepository episodeRepo;
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
    episodeRepo = EpisodeRepository(db);
    sync = LibraryMetadataSyncService(
      repo,
      tmdb,
      IntelligentNameRecognizer(http.Client()),
      episodeRepo,
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

  group('手动修正匹配与重新识别测试', () {
    test('TmdbMetadataService.searchAll 能获取完整的检索列表并排序', () async {
      handler = (request) async {
        if (request.uri.path == '/search/movie') {
          request.response
            ..statusCode = 200
            ..write(
              jsonEncode({
                'results': [
                  {
                    'id': 101,
                    'title': '黑客帝国',
                    'poster_path': '/matrix1.jpg',
                    'release_date': '1999-03-30',
                    'overview': 'Matrix movie 1',
                  },
                  {
                    'id': 102,
                    'title': '黑客帝国2：重装上阵',
                    'poster_path': '/matrix2.jpg',
                    'release_date': '2003-05-15',
                    'overview': 'Matrix movie 2',
                  },
                ],
              }),
            );
        } else if (request.uri.path == '/search/tv') {
          request.response
            ..statusCode = 200
            ..write(
              jsonEncode({
                'results': [
                  {
                    'id': 201,
                    'name': '黑客帝国动画版',
                    'poster_path': '/matrix_tv.jpg',
                    'first_air_date': '2003-06-03',
                    'overview': 'Matrix TV Show',
                  },
                ],
              }),
            );
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      };

      // 搜索全部类型
      final results = await tmdb.searchAll('黑客帝国', 'mock-key');

      expect(results.length, 3);
      expect(
        results.any((r) => r.id == 101 && r.type == MediaType.movie),
        isTrue,
      );
      expect(results.any((r) => r.id == 201 && r.type == MediaType.tv), isTrue);
      expect(results[0].title, '黑客帝国动画版'); // 按照年份最新排序
    });

    test('manualMatch 电影变电视剧时，能成功写入默认剧集', () async {
      handler = (request) async {
        if (request.uri.path == '/tv/201') {
          request.response
            ..statusCode = 200
            ..write(
              jsonEncode({
                'id': 201,
                'name': '黑客帝国动画版',
                'first_air_date': '2003-06-03',
                'overview': 'Matrix TV Show Details',
                'poster_path': '/matrix_tv.jpg',
                'backdrop_path': '/matrix_tv_bd.jpg',
                'vote_average': 8.5,
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

      // 初始数据：是一部电影
      final media = const Media(
        id: '/movies/matrix.mkv',
        title: 'Matrix',
        year: '1999',
        type: MediaType.movie,
        path: '/movies/matrix.mkv',
        fullPath: '/movies/matrix.mkv',
      );
      await repo.upsert(media);

      // 此时剧集库为空
      final epsBefore = await episodeRepo.getByShow(media.id);
      expect(epsBefore, isEmpty);

      // 修正匹配为电视剧
      final success = await sync.manualMatch(
        mediaId: media.id,
        tmdbId: 201,
        type: MediaType.tv,
        apiKey: 'mock-key',
      );

      expect(success, isTrue);

      final updated = await repo.getById(media.id);
      expect(updated, isNotNull);
      expect(updated!.type, MediaType.tv);
      expect(updated.title, '黑客帝国动画版');
      expect(updated.tmdbId, 201);

      // 校验自动生成的默认剧集是否存在
      final epsAfter = await episodeRepo.getByShow(media.id);
      expect(epsAfter, isNotEmpty);
      expect(epsAfter.length, 1);
      expect(epsAfter[0].seasonNumber, 1);
      expect(epsAfter[0].episodeNumber, 1);
      expect(epsAfter[0].showId, media.id);
    });

    test('manualMatch 电视剧变电影时，能清除关联的所有剧集', () async {
      handler = (request) async {
        if (request.uri.path == '/movie/101') {
          request.response
            ..statusCode = 200
            ..write(
              jsonEncode({
                'id': 101,
                'title': '黑客帝国',
                'release_date': '1999-03-30',
                'overview': 'Neo wakes up.',
                'poster_path': '/matrix.jpg',
                'backdrop_path': '/matrix_bd.jpg',
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

      // 初始为电视剧，并写入了剧集
      final media = const Media(
        id: '/movies/matrix.mkv',
        title: 'Matrix TV',
        year: '1999',
        type: MediaType.tv,
        path: '/movies/matrix.mkv',
        fullPath: '/movies/matrix.mkv',
      );
      await repo.upsert(media);

      final episode = const Episode(
        id: '/movies/matrix.mkv_s1e1',
        showId: '/movies/matrix.mkv',
        seasonNumber: 1,
        episodeNumber: 1,
        title: 'Episode 1',
        path: '/movies/matrix.mkv',
        dateAdded: '',
      );
      await episodeRepo.upsert(episode);

      final epsBefore = await episodeRepo.getByShow(media.id);
      expect(epsBefore.length, 1);

      // 修正匹配为电影
      final success = await sync.manualMatch(
        mediaId: media.id,
        tmdbId: 101,
        type: MediaType.movie,
        apiKey: 'mock-key',
      );

      expect(success, isTrue);

      final updated = await repo.getById(media.id);
      expect(updated, isNotNull);
      expect(updated!.type, MediaType.movie);
      expect(updated.title, '黑客帝国');

      // 校验关联剧集被清除
      final epsAfter = await episodeRepo.getByShow(media.id);
      expect(epsAfter, isEmpty);
    });
  });
}
