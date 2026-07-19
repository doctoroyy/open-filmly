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
///
/// Unmatched / obvious non-entertainment items go to [LibraryShelf.other]
/// instead of polluting 电影/电视剧.
class LibraryShelfClassifier {
  LibraryShelfClassifier._();

  // Folder-level anime signals only. Bare 「动画」 is NOT used on free text —
  // it false-positives CSS/Vue/React tutorials ("过渡和动画", "动画插件").
  static final _pathAnimeFolder = RegExp(
    r'(?:^|[/\\])(?:动漫|动画片|番剧|anime|アニメ)(?:[/\\]|$)',
    caseSensitive: false,
  );
  static final _pathVariety = RegExp(r'综艺|variety|真人秀', caseSensitive: false);
  static final _pathConcert = RegExp(
    r'演唱会|concert|live\s*tour|巡演',
    caseSensitive: false,
  );
  static final _pathDocumentary = RegExp(
    r'纪录片|documentary',
    caseSensitive: false,
  );

  // Courses / programming lessons / non-entertainment dumps → 其他.
  static final _nonMediaCourse = RegExp(
    r'课件|教程|教育|大师课|源码|前端|后端|小程序|编程|有声书|听书|软件|系统镜像|'
    r'\bcss3?\b|\bhtml5?\b|\bvue\b|\breact\b|\bjavascript\b|\btypescript\b|'
    r'\bnode\.?js\b|\bwebpack\b|\bnuxt\b|\bscss\b|\banimate\.css\b|'
    r'\bubuntu\b|\bwindows\b|\.iso\b|\bsample\b|\btrailer\b|'
    r'渡一|慕课|网易云课堂|极客时间',
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

  /// UI / web 「动画」 phrasing that is NOT anime.
  static final _uiAnimationNoise = RegExp(
    r'过渡和动画|动画插件|动画事件|动画案例|简单动画|'
    r'css3?\s*动画|react\s*动画|vue\s*动画|js\s*动画|'
    r'路由切换动画|交互动画',
    caseSensitive: false,
  );

  /// Numbered lesson / chapter titles: "02 CSS3…", "1 1 React…", "第3讲".
  static final _lessonTitle = RegExp(
    r'^(?:\d{1,2}(?:[\s._\-]+\d{1,2}){0,3}[\s._\-]+|'
    r'第[一二三四五六七八九十百\d]+[讲章节课课次])',
  );

  /// zh-CN genre names as stored by TMDB with `language=zh-CN`.
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
    final title = media.title.trim();
    final haystack = '$pathBlob $title';
    final genres = media.genres
        .map((g) => g.trim().toLowerCase())
        .where((g) => g.isNotEmpty)
        .toList(growable: false);

    // 0) Non-entertainment courses / dumps / samples always → 其他.
    if (_nonMediaCourse.hasMatch(haystack) ||
        _uiAnimationNoise.hasMatch(haystack) ||
        _lessonTitle.hasMatch(title)) {
      return LibraryShelf.other;
    }

    // 1) Path heuristics (work before scrape). Genre-specific folders first.
    if (_pathAnimeFolder.hasMatch(pathBlob)) return LibraryShelf.anime;
    if (_pathVariety.hasMatch(pathBlob)) return LibraryShelf.variety;
    if (_pathConcert.hasMatch(pathBlob)) return LibraryShelf.concert;
    if (_pathDocumentary.hasMatch(pathBlob)) return LibraryShelf.documentary;

    // 2) Genre rules only apply when TMDB (or equivalent scrape) filled them.
    //    Unmatched rows must not use leftover empty genres to sneak into 电影.
    if (_hasTmdbMatch(media)) {
      if (_hasAnyGenre(genres, _genreAnime) &&
          (_titleAnime.hasMatch(title) ||
              _titleAnime.hasMatch(pathBlob) ||
              media.type == MediaType.tv ||
              _looksLikeAnimeTitle(title))) {
        return LibraryShelf.anime;
      }
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

      // 3) Matched: place by MediaType.
      return switch (media.type) {
        MediaType.movie => LibraryShelf.movie,
        MediaType.tv => LibraryShelf.tv,
        MediaType.unknown => LibraryShelf.other,
      };
    }

    // 4) Strict: no TMDB id → 其他.
    //    Folder labels above (动漫/综艺/…) still win so curated dirs work
    //    before scrape finishes; 电影/电视剧 main shelves require a match.
    return LibraryShelf.other;
  }

  static bool matches(Media media, LibraryShelf shelf) =>
      classify(media) == shelf;

  /// TMDB scrape succeeded (id stored in details JSON).
  static bool _hasTmdbMatch(Media media) {
    final id = media.tmdbId;
    if (id == null) return false;
    if (id is num) return true;
    final s = id.toString().trim();
    return s.isNotEmpty && s != 'null';
  }

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

  static bool _looksLikeAnimeTitle(String title) {
    return RegExp(r'[\u3040-\u30ff]').hasMatch(title);
  }
}
