import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/models/library_shelf.dart';
import 'package:open_filmly/data/models/media.dart';

Media _media({
  required String id,
  required String title,
  required MediaType type,
  String path = '/media/item.mkv',
  String? fullPath,
  List<String> genres = const [],
}) {
  return Media(
    id: id,
    title: title,
    year: '2020',
    type: type,
    path: path,
    fullPath: fullPath,
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
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.variety);
    });

    test('zh-CN 脱口秀 → variety', () {
      final m = _media(
        id: '5',
        title: '脱口秀大会',
        type: MediaType.tv,
        genres: const ['脱口秀'],
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
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.concert);
    });

    test('plain movie without special genres → movie', () {
      final m = _media(
        id: '7',
        title: '肖申克的救赎',
        type: MediaType.movie,
        path: '/movies/shawshank.mkv',
        genres: const ['剧情', '犯罪'],
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.movie);
    });

    test('plain tv series → tv', () {
      final m = _media(
        id: '8',
        title: '怪奇物语',
        type: MediaType.tv,
        path: '/tv/stranger/S01E01.mkv',
        genres: const ['剧情', '科幻', '神秘'],
      );
      expect(LibraryShelfClassifier.classify(m), LibraryShelf.tv);
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

    test('each media maps to exactly one shelf (partition)', () {
      final samples = [
        _media(
          id: 'a',
          title: '动画电影',
          type: MediaType.movie,
          genres: const ['动画'],
        ),
        _media(
          id: 'b',
          title: '普通电影',
          type: MediaType.movie,
          genres: const ['动作'],
        ),
        _media(id: 'c', title: '剧集', type: MediaType.tv, genres: const ['剧情']),
        _media(
          id: 'd',
          title: '纪录',
          type: MediaType.movie,
          genres: const ['纪录'],
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
