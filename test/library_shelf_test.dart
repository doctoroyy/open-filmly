import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/models/library_shelf.dart';
import 'package:open_filmly/data/models/media.dart';

Media _media({
  required String id,
  required String title,
  required MediaType type,
  String path = '/media/item.mkv',
  String? fullPath,
  String year = '2020',
  String? posterPath,
  String? detailsJson,
  List<String> genres = const [],
}) {
  return Media(
    id: id,
    title: title,
    year: year,
    type: type,
    path: path,
    fullPath: fullPath,
    posterPath: posterPath,
    detailsJson: detailsJson,
    genres: genres,
  );
}

void main() {
  group('LibraryShelfClassifier exclusive shelves', () {
    test('path 动漫 folder wins over movie type', () {
      final m = _media(
        id: '1',
        title: '某番剧',
        type: MediaType.movie,
        path: '/Volumes/nas/动漫/某番剧/ep01.mkv',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.anime);
    });

    test('zh-CN genre 动画 → anime (not movie)', () {
      final m = _media(
        id: '2',
        title: '千与千寻',
        type: MediaType.movie,
        path: '/movies/Spirited.Away.mkv',
        genres: const ['动画', '家庭', '奇幻'],
        detailsJson: '{"tmdbId": 129}',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.anime);
      expect(LibraryShelfClassifier.matches(m, LibraryShelf.movie), isFalse);
    });

    test('zh-CN genre 纪录 → documentary', () {
      final m = _media(
        id: '3',
        title: '地球脉动',
        type: MediaType.tv,
        path: '/tv/Planet.Earth.mkv',
        genres: const ['纪录'],
        detailsJson: '{"tmdbId": 1}',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.documentary);
      expect(LibraryShelfClassifier.matches(m, LibraryShelf.tv), isFalse);
    });

    test('zh-CN genre 真人秀 → variety', () {
      final m = _media(
        id: '4',
        title: '某综艺',
        type: MediaType.tv,
        path: '/tv/show.mkv',
        genres: const ['真人秀'],
        detailsJson: '{"tmdbId": 2}',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.variety);
    });

    test('zh-CN 脱口秀 → variety', () {
      final m = _media(
        id: '5',
        title: '脱口秀大会',
        type: MediaType.tv,
        genres: const ['脱口秀'],
        detailsJson: '{"tmdbId": 3}',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.variety);
    });

    test('音乐 + 演唱会 title → concert', () {
      final m = _media(
        id: '6',
        title: '周杰伦 2024 演唱会',
        type: MediaType.movie,
        path: '/music/jay.mkv',
        genres: const ['音乐'],
        detailsJson: '{"tmdbId": 4}',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.concert);
    });

    test('plain movie with TMDB → movie', () {
      final m = _media(
        id: '7',
        title: '肖申克的救赎',
        type: MediaType.movie,
        path: '/movies/shawshank.mkv',
        genres: const ['剧情', '犯罪'],
        detailsJson: '{"tmdbId": 278}',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.movie);
    });

    test('plain tv series with TMDB → tv', () {
      final m = _media(
        id: '8',
        title: '怪奇物语',
        type: MediaType.tv,
        path: '/tv/stranger/S01E01.mkv',
        genres: const ['剧情', '科幻', '神秘'],
        detailsJson: '{"tmdbId": 66732}',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.tv);
    });

    test('无 TMDB 的一律进其他（含 /电影/ 路径）', () {
      final samples = [
        _media(
          id: 'u1',
          title: '肖申克的救赎',
          type: MediaType.movie,
          path: '/movies/shawshank.mkv',
        ),
        _media(
          id: 'u2',
          title: 'The Batman',
          type: MediaType.movie,
          path: '/Volumes/wd/电影/新蝙蝠侠/The.Batman.2022.mkv',
          year: '2022',
        ),
        _media(
          id: 'u3',
          title: '怪奇物语',
          type: MediaType.tv,
          path: '/tv/stranger/S01E01.mkv',
        ),
      ];
      for (final m in samples) {
        expect(
          LibraryShelfClassifier.classify(m),
          LibraryShelf.other,
          reason: m.title,
        );
      }
    });

    test('unknown type without signals → other', () {
      final m = _media(
        id: '9',
        title: '杂项文件',
        type: MediaType.unknown,
        path: '/misc/file.mkv',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.other);
    });

    test('path 纪录片 beats type tv', () {
      final m = _media(
        id: '10',
        title: '未知纪录',
        type: MediaType.tv,
        path: '/Volumes/share/纪录片/nature.mkv',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.documentary);
    });

    test('CSS/Vue 课程「动画」不进动漫，归其他', () {
      final samples = [
        _media(
          id: 'c1',
          title: '02 CSS3过渡和动画',
          type: MediaType.movie,
          path: '/wd/aria2-downloads/【渡一教育】WEB前端大师课/01 技术提升/02. CSS3过渡和动画.mp4',
        ),
        _media(
          id: 'c2',
          title: '11 2 动画插件',
          type: MediaType.movie,
          path: '/wd/aria2-downloads/课件/11.2. 动画插件.mp4',
        ),
        _media(
          id: 'c3',
          title: '4 14 React动画 1',
          type: MediaType.movie,
          path: '/wd/downloads/React动画1.mp4',
        ),
      ];
      for (final m in samples) {
        expect(
          LibraryShelfClassifier.classify(m),
          LibraryShelf.other,
          reason: m.title,
        );
      }
    });

    test('真实 /动漫/ 路径仍进动漫', () {
      final m = _media(
        id: 'a1',
        title: '进击的巨人',
        type: MediaType.tv,
        path: '/Volumes/nas/动漫/进击的巨人/S01E01.mkv',
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.anime);
    });

    test('未匹配的明显垃圾不进电影/电视剧', () {
      final samples = [
        _media(
          id: 'j1',
          title: '18',
          type: MediaType.movie,
          year: '',
          path: '/aria2-downloads/唐朝诡事录.4K.内封/18.mkv',
        ),
        _media(
          id: 'j2',
          title: 'Sample TBHM10',
          type: MediaType.movie,
          year: '',
          path: '/aria2-downloads/Tenet/Sample/Sample-TBHM10.mkv',
        ),
        _media(
          id: 'j3',
          title: 'ubuntu 20 04 3 desktop amd64',
          type: MediaType.movie,
          year: '',
          path: '/aria2-downloads/ubuntu-20.04.3-desktop-amd64.iso',
        ),
        _media(
          id: 'j4',
          title: '01 计程车招呼站 TREX',
          type: MediaType.movie,
          year: '',
          path: '/aria2-downloads/有声书/电视剧/D 都市惧集/01-计程车招呼站.TREX.mp4',
        ),
      ];
      for (final m in samples) {
        expect(
          LibraryShelfClassifier.classify(m),
          LibraryShelf.other,
          reason: m.title,
        );
      }
    });

    test('有 TMDB 才进电影', () {
      expect(
        LibraryShelfClassifier.classify(
          _media(
            id: 'ok1',
            title: '教父',
            type: MediaType.movie,
            path: '/btsync/IMDB TOP 250/002.教父.The.Godfather.mkv',
            detailsJson: '{"tmdbId": 238}',
          ),
        ),
        LibraryShelf.movie,
      );
      // Poster alone is not enough — requires tmdbId.
      expect(
        LibraryShelfClassifier.classify(
          _media(
            id: 'ok3',
            title: '阿凡达',
            type: MediaType.movie,
            path: '/movies/avatar.mkv',
            posterPath: 'https://image.tmdb.org/t/p/w500/x.jpg',
          ),
        ),
        LibraryShelf.other,
      );
    });

    test('each media maps to exactly one shelf (partition)', () {
      final samples = [
        _media(
          id: 'a',
          title: '动画电影',
          type: MediaType.movie,
          genres: const ['动画'],
          detailsJson: '{"tmdbId": 10}',
        ),
        _media(
          id: 'b',
          title: '普通电影',
          type: MediaType.movie,
          genres: const ['动作'],
          detailsJson: '{"tmdbId": 11}',
        ),
        _media(
          id: 'c',
          title: '剧集',
          type: MediaType.tv,
          genres: const ['剧情'],
          detailsJson: '{"tmdbId": 12}',
        ),
        _media(
          id: 'd',
          title: '纪录',
          type: MediaType.movie,
          genres: const ['纪录'],
          detailsJson: '{"tmdbId": 13}',
        ),
      ];
      for (final m in samples) {
        final shelf = LibraryShelfClassifier.classify(m);
        final hits = LibraryShelf.values
            .where((s) => LibraryShelfClassifier.matches(m, s))
            .toList();
        expect(hits, [shelf], reason: m.title);
      }
    });
  });
}
