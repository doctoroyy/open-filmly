import 'media.dart';

/// Exclusive library shelves used by the sidebar (NetEase 爆米花 style).
///
/// Each [Media] maps to **exactly one** shelf via [LibraryShelfClassifier].
/// "最近观看" is NOT a shelf — it comes from playback progress, not media rows.
enum LibraryShelf {
  movie,
  tv,
  anime,
  variety,
  concert,
  documentary,
  other;

  String get label => switch (this) {
    LibraryShelf.movie => '电影',
    LibraryShelf.tv => '电视剧',
    LibraryShelf.anime => '动漫',
    LibraryShelf.variety => '综艺',
    LibraryShelf.concert => '演唱会',
    LibraryShelf.documentary => '纪录片',
    LibraryShelf.other => '其他',
  };
}

/// Pure-function classifier: path heuristics first, then zh-CN TMDB genres,
/// then MediaType fallback. One media → one shelf (mutually exclusive).
class LibraryShelfClassifier {
  LibraryShelfClassifier._();

  // Path / folder / title tokens (case-insensitive for ASCII).
  static final _pathAnime = RegExp(r'动漫|动画|anime|アニメ', caseSensitive: false);
  static final _pathVariety = RegExp(r'综艺|variety|真人秀', caseSensitive: false);
  static final _pathConcert = RegExp(
    r'演唱会|concert|live\s*tour|巡演',
    caseSensitive: false,
  );
  static final _pathDocumentary = RegExp(
    r'纪录片|documentary|纪录',
    caseSensitive: false,
  );

  // Title-level anime signals (when genres alone are weak).
  static final _titleAnime = RegExp(
    r'anime|アニメ|番剧|OVA|OAD',
    caseSensitive: false,
  );
  static final _titleConcert = RegExp(
    r'演唱会|concert|live\s*(in|at|tour)|巡演|live album',
    caseSensitive: false,
  );

  /// zh-CN genre names as stored by TMDB with `language=zh-CN`.
  /// Also accept a few English aliases for robustness.
  static const _genreAnime = {'动画', 'animation'};
  static const _genreDocumentary = {'纪录', '纪录片', 'documentary'};
  static const _genreVariety = {
    '真人秀',
    '脱口秀',
    'reality',
    'talk show',
    'talk-show',
  };
  static const _genreMusic = {'音乐', 'music'};

  /// Assigns a single exclusive shelf for [media].
  static LibraryShelf classify(Media media) {
    final pathBlob = _pathBlob(media);
    final title = media.title;
    final genres = media.genres
        .map((g) => g.trim().toLowerCase())
        .where((g) => g.isNotEmpty)
        .toList(growable: false);

    // 1) Path heuristics (work before scrape).
    if (_pathAnime.hasMatch(pathBlob)) return LibraryShelf.anime;
    if (_pathVariety.hasMatch(pathBlob)) return LibraryShelf.variety;
    if (_pathConcert.hasMatch(pathBlob)) return LibraryShelf.concert;
    if (_pathDocumentary.hasMatch(pathBlob)) return LibraryShelf.documentary;

    // 2) Genre rules (zh-CN primary). Priority: anime > documentary >
    //    variety > concert (music + concert signal).
    if (_hasAnyGenre(genres, _genreAnime) &&
        (_titleAnime.hasMatch(title) ||
            _titleAnime.hasMatch(pathBlob) ||
            media.type == MediaType.tv ||
            _looksLikeAnimeTitle(title))) {
      return LibraryShelf.anime;
    }
    // Pure Animation genre without extra anime signals → still anime
    // (covers 宫崎骏电影 etc., matching 爆米花 动漫 shelf).
    if (_hasAnyGenre(genres, _genreAnime)) {
      return LibraryShelf.anime;
    }
    if (_hasAnyGenre(genres, _genreDocumentary)) {
      return LibraryShelf.documentary;
    }
    if (_hasAnyGenre(genres, _genreVariety)) {
      return LibraryShelf.variety;
    }
    if (_hasAnyGenre(genres, _genreMusic) &&
        (_titleConcert.hasMatch(title) || _titleConcert.hasMatch(pathBlob))) {
      return LibraryShelf.concert;
    }

    // 3) MediaType fallback.
    return switch (media.type) {
      MediaType.movie => LibraryShelf.movie,
      MediaType.tv => LibraryShelf.tv,
      MediaType.unknown => LibraryShelf.other,
    };
  }

  static bool matches(Media media, LibraryShelf shelf) =>
      classify(media) == shelf;

  static String _pathBlob(Media media) {
    final parts = <String>[
      media.path,
      if (media.fullPath != null) media.fullPath!,
    ];
    return parts.join(' ');
  }

  static bool _hasAnyGenre(List<String> genres, Set<String> needles) {
    for (final g in genres) {
      for (final n in needles) {
        if (g == n || g.contains(n)) return true;
      }
    }
    return false;
  }

  /// Soft heuristic for Japanese-style anime titles when genre is Animation.
  static bool _looksLikeAnimeTitle(String title) {
    // Hiragana / Katakana present.
    return RegExp(r'[\u3040-\u30ff]').hasMatch(title);
  }
}
