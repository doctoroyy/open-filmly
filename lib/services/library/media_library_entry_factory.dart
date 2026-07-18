import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:smb_connect/smb_connect.dart';

import '../../data/models/episode.dart';
import '../../data/models/media.dart';
import '../smb/smb_service.dart';

/// Parsed source metadata for a media item.
class SmbMediaSource {
  const SmbMediaSource({
    required this.host,
    required this.path,
    required this.share,
    this.domain = '',
    this.username = '',
  });

  final String host;
  final String path;
  final String share;
  final String domain;
  final String username;
}

/// Parsed WebDAV source metadata for a media item.
class WebDavMediaSource {
  const WebDavMediaSource({required this.baseUrl, required this.path});

  /// The WebDAV root URL the item was imported from.
  final String baseUrl;

  /// Server-relative path of the file (or show directory) on that server.
  final String path;
}

/// Parsed Emby/Jellyfin source metadata for a media item.
class EmbyMediaSource {
  const EmbyMediaSource({required this.baseUrl, required this.itemId});

  /// The Emby/Jellyfin server base URL.
  final String baseUrl;

  /// The server item id to stream.
  final String itemId;
}

/// Result of processing a video file: either a standalone movie [Media],
/// or a TV show [Media] plus its [Episode].
class LibraryEntry {
  const LibraryEntry({required this.media, this.episode});

  final Media media;
  final Episode? episode;

  bool get hasEpisode => episode != null;
}

/// Shared factory for turning local files or SMB files into library items.
class MediaLibraryEntryFactory {
  static const videoExtensions = {
    '.mkv',
    '.mp4',
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.webm',
    '.m4v',
    '.mpg',
    '.mpeg',
    '.ts',
    '.m2ts',
    '.rmvb',
    '.rm',
    '.vob',
    '.iso',
  };

  static final _episodePattern = RegExp(
    r'\bS(\d{1,2})E(\d{1,2})\b',
    caseSensitive: false,
  );

  /// Matches a directory segment that is purely a season container, including
  /// common Chinese pack layouts like `S01.第一季`, `S02 第二季`, `第一季`,
  /// `Season 1`, and bare `S01`.
  static final _seasonPattern = RegExp(
    r'^(?:'
    r'season\s*\d+'
    r'|s\d{1,2}(?:\s*[.\-_\s]\s*第[一二三四五六七八九十百\d]+季)?'
    r'|第[一二三四五六七八九十百\d]+季'
    r')$',
    caseSensitive: false,
  );

  /// True when a cleaned title is just a season token (S01 / 第一季 / Season 2)
  /// and therefore cannot be the show name.
  static final _seasonOnlyTitlePattern = RegExp(
    r'^(?:s\d{1,2}|season\s*\d+|第[一二三四五六七八九十百\d]+季)$',
    caseSensitive: false,
  );

  /// Pattern to extract the show title from a filename before the S01E01 tag.
  /// Requires a non-empty title prefix so bare `S01E01.Pilot` does not match.
  static final _showTitleFromFilenamePattern = RegExp(
    r'^(.+?)\s*[.\s_\-]S\d{1,2}E\d{1,2}',
    caseSensitive: false,
  );
  static final _yearPattern = RegExp(r'(19|20)\d{2}');

  /// Release-name noise stripped from titles: resolutions, sources, codecs,
  /// audio formats, HDR tags, and well-known release group names. Keeping the
  /// title clean makes the poster wall readable and TMDB search accurate.
  static final _cleanupPattern = RegExp(
    r'\b(2160p|1080p|720p|480p|4k|uhd|bluray|blu-ray|brrip|bdrip|dvdrip|'
    r'webrip|web-dl|webdl|web|hdtv|remux|encode|'
    r'x264|x265|h264|h265|h\.264|h\.265|hevc|avc|av1|10bit|8bit|'
    r'aac|aac2\.0|ddp?5\.1|dd5\.1|eac3|ac3|dts|dts-hd|truehd|flac|atmos|ma|'
    r'\d+audios?|'
    r'hdr|hdr10|hdr10\+|dovi|dv|sdr|60fps|hq|'
    r'proper|repack|extended|unrated|imax|remastered|'
    r'dc|director\x27?s\.?cut|theatrical|criterion|'
    r'mnhd|frds|cmct|wiki|chd|hds|tlf|sparks|rarbg|yts|yify|fgt)\b',
    caseSensitive: false,
  );

  /// CJK release tags — matched without \b since word boundaries don't apply
  /// to CJK characters in Dart regexes.
  static final _cjkCleanupPattern = RegExp(r'(国语|粤语|中字|双语|简繁|内封|内嵌|特效字幕)');

  /// True when [title] still carries release-name noise (codec/source/group
  /// tags). Used by the startup hygiene pass to retitle only entries that
  /// actually need it, leaving curated titles untouched.
  static bool titleLooksDirty(String title) {
    return _cleanupPattern.hasMatch(title) ||
        _cjkCleanupPattern.hasMatch(title);
  }

  static bool isVideoPath(String filePath) {
    return videoExtensions.contains(path.extension(filePath).toLowerCase());
  }

  /// True for OS junk / metadata files that look like videos but aren't:
  /// macOS AppleDouble sidecars (`._foo.mkv`), dotfiles, sample clips, and
  /// the Trash. These must be skipped so they don't pollute the library or
  /// create phantom duplicates of every real title.
  static bool isJunkPath(String filePath) {
    final name = path.basename(filePath);
    if (name.startsWith('._') || name.startsWith('.')) return true;
    final lower = filePath.toLowerCase();
    if (lower.contains('/.trash') ||
        lower.contains('/\$recycle.bin') ||
        lower.contains('/@eadir')) {
      return true;
    }
    // "sample"/"trailer" clips that sit beside the real file.
    final base = path.basenameWithoutExtension(name).toLowerCase();
    if (base == 'sample' ||
        base.endsWith('-sample') ||
        base.endsWith('.sample') ||
        base == 'trailer') {
      return true;
    }
    return false;
  }

  /// A path worth importing: a real video that isn't OS junk.
  static bool isImportableVideo(String filePath) =>
      isVideoPath(filePath) && !isJunkPath(filePath);

  static LibraryEntry fromLocalPath(String filePath) {
    final normalized = path.normalize(filePath);
    final logicalPath = _logicalPath(normalized);
    final basename = path.basenameWithoutExtension(normalized);
    final type = _detectType(logicalPath, basename);
    final title = _titleFor(type, logicalPath, basename);
    final year = _extractYear(logicalPath);

    if (type == MediaType.tv) {
      final showId = _tvShowId(title);
      final media = Media(
        id: showId,
        title: title,
        year: year,
        type: MediaType.tv,
        path: _tvShowDirectory(normalized),
        fullPath: _tvShowDirectory(normalized),
      );
      final episode = _parseEpisode(
        id: normalized,
        showId: showId,
        logicalPath: logicalPath,
        basename: basename,
        filePath: normalized,
        fullPath: normalized,
      );
      return LibraryEntry(media: media, episode: episode);
    }

    final media = Media(
      id: normalized,
      title: title,
      year: year,
      type: type,
      path: normalized,
      fullPath: normalized,
    );
    return LibraryEntry(media: media);
  }

  static LibraryEntry fromSmbFile({
    required SmbConfig config,
    required SmbFile file,
  }) {
    final logicalPath = _logicalPath(file.path);
    final basename = path.basenameWithoutExtension(file.path);
    final type = _detectType(logicalPath, basename);
    final title = _titleFor(type, logicalPath, basename);
    final year = _extractYear(logicalPath);
    final smbUri = 'smb://${config.host}${_ensureLeadingSlash(file.path)}';

    if (type == MediaType.tv) {
      final showId = _sourceScopedTvShowId(
        'smb',
        '${config.host.toLowerCase()}|${file.share.toLowerCase()}',
        title,
      );
      final media = Media(
        id: showId,
        title: title,
        year: year,
        type: MediaType.tv,
        path: showId,
        fullPath: _tvShowDirectoryFromPath(logicalPath),
        detailsJson: jsonEncode({
          'source': {
            'kind': 'smb',
            'host': config.host,
            'path': _tvShowDirectoryFromPath(logicalPath),
            'share': file.share,
            'domain': config.domain,
            'username': config.username,
          },
        }),
      );
      final episode = _parseEpisode(
        id: smbUri,
        showId: showId,
        logicalPath: logicalPath,
        basename: basename,
        filePath: smbUri,
        fullPath: file.path,
      );
      return LibraryEntry(media: media, episode: episode);
    }

    final media = Media(
      id: smbUri,
      title: title,
      year: year,
      type: type,
      path: smbUri,
      fullPath: file.path,
      detailsJson: jsonEncode({
        'source': {
          'kind': 'smb',
          'host': config.host,
          'path': file.path,
          'share': file.share,
          'domain': config.domain,
          'username': config.username,
        },
      }),
    );
    return LibraryEntry(media: media);
  }

  /// Legacy compatibility: produce a flat [Media] from a local path without
  /// episode extraction.
  static Media flatMediaFromLocalPath(String filePath) {
    final normalized = path.normalize(filePath);
    final logicalPath = _logicalPath(normalized);
    final basename = path.basenameWithoutExtension(normalized);
    final type = _detectType(logicalPath, basename);
    final title = _titleFor(type, logicalPath, basename);
    final year = _extractYear(logicalPath);

    return Media(
      id: normalized,
      title: title,
      year: year,
      type: type,
      path: normalized,
      fullPath: normalized,
    );
  }

  /// Legacy compatibility: produce a flat [Media] from an SMB file.
  static Media flatMediaFromSmbFile({
    required SmbConfig config,
    required SmbFile file,
  }) {
    final logicalPath = _logicalPath(file.path);
    final basename = path.basenameWithoutExtension(file.path);
    final type = _detectType(logicalPath, basename);
    final title = _titleFor(type, logicalPath, basename);
    final year = _extractYear(logicalPath);
    final smbUri = 'smb://${config.host}${_ensureLeadingSlash(file.path)}';

    return Media(
      id: smbUri,
      title: title,
      year: year,
      type: type,
      path: smbUri,
      fullPath: file.path,
      detailsJson: jsonEncode({
        'source': {
          'kind': 'smb',
          'host': config.host,
          'path': file.path,
          'share': file.share,
          'domain': config.domain,
          'username': config.username,
        },
      }),
    );
  }

  static SmbMediaSource? smbSourceFor(Media media) {
    final raw = media.detailsJson;
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final source = decoded['source'];
      if (source is! Map<String, dynamic>) return null;
      if (source['kind'] != 'smb') return null;

      final host = source['host']?.toString() ?? '';
      final sourcePath = source['path']?.toString() ?? '';
      final share = source['share']?.toString() ?? '';
      if (host.isEmpty || sourcePath.isEmpty || share.isEmpty) return null;

      return SmbMediaSource(
        host: host,
        path: sourcePath,
        share: share,
        domain: source['domain']?.toString() ?? '',
        username: source['username']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Builds a library entry from a WebDAV file. [relativePath] is the file's
  /// server path (e.g. `/Movies/Dune.2021.mkv`); [baseUrl] is the WebDAV root.
  static LibraryEntry fromWebDavFile({
    required String baseUrl,
    required String relativePath,
  }) {
    final logicalPath = _logicalPath(relativePath);
    final basename = path.basenameWithoutExtension(relativePath);
    final type = _detectType(logicalPath, basename);
    final title = _titleFor(type, logicalPath, basename);
    final year = _extractYear(logicalPath);
    final id = _webDavId(baseUrl, relativePath);

    if (type == MediaType.tv) {
      final showDir = _tvShowDirectoryFromPath(logicalPath);
      final showId = _sourceScopedTvShowId(
        'webdav',
        baseUrl.trim().toLowerCase(),
        title,
      );
      final media = Media(
        id: showId,
        title: title,
        year: year,
        type: MediaType.tv,
        path: showId,
        fullPath: showDir,
        detailsJson: jsonEncode({
          'source': {'kind': 'webdav', 'base': baseUrl, 'path': '/$showDir'},
        }),
      );
      final episode = _parseEpisode(
        id: id,
        showId: showId,
        logicalPath: logicalPath,
        basename: basename,
        filePath: id,
        fullPath: relativePath,
      );
      return LibraryEntry(media: media, episode: episode);
    }

    final media = Media(
      id: id,
      title: title,
      year: year,
      type: type,
      path: id,
      fullPath: relativePath,
      detailsJson: jsonEncode({
        'source': {'kind': 'webdav', 'base': baseUrl, 'path': relativePath},
      }),
    );
    return LibraryEntry(media: media);
  }

  /// Extracts WebDAV source info from a stored media item, or null.
  static WebDavMediaSource? webDavSourceFor(Media media) {
    final raw = media.detailsJson;
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final source = decoded['source'];
      if (source is! Map<String, dynamic>) return null;
      if (source['kind'] != 'webdav') return null;

      final base = source['base']?.toString() ?? '';
      final sourcePath = source['path']?.toString() ?? '';
      if (base.isEmpty || sourcePath.isEmpty) return null;

      return WebDavMediaSource(baseUrl: base, path: sourcePath);
    } catch (_) {
      return null;
    }
  }

  static String _webDavId(String baseUrl, String relativePath) {
    return 'webdav|$baseUrl|$relativePath';
  }

  /// Builds a flat movie/show [Media] from an Emby/Jellyfin item. TV episodes
  /// are handled separately (see [fromEmbyEpisode]) because Emby provides
  /// structured season/episode data via its API.
  static Media fromEmbyMovieOrShow({
    required String baseUrl,
    required String itemId,
    required String title,
    required String year,
    required bool isSeries,
    String? posterUrl,
    String? overview,
  }) {
    return Media(
      id: 'emby|$baseUrl|$itemId',
      title: title,
      year: year,
      type: isSeries ? MediaType.tv : MediaType.movie,
      path: 'emby|$baseUrl|$itemId',
      fullPath: itemId,
      posterPath: posterUrl,
      detailsJson: jsonEncode({
        'source': {'kind': 'emby', 'base': baseUrl, 'itemId': itemId},
        if (overview != null && overview.isNotEmpty) 'overview': overview,
      }),
    );
  }

  /// Builds an [Episode] from an Emby/Jellyfin episode item belonging to
  /// [showId] (the local show media id).
  static Episode fromEmbyEpisode({
    required String showId,
    required String itemId,
    required int seasonNumber,
    required int episodeNumber,
    required String title,
  }) {
    return Episode(
      id: 'emby-ep|$itemId',
      showId: showId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      title: title,
      path: itemId,
      fullPath: itemId,
    );
  }

  /// Extracts Emby/Jellyfin source info from a stored media item, or null.
  static EmbyMediaSource? embySourceFor(Media media) {
    final raw = media.detailsJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final source = decoded['source'];
      if (source is! Map<String, dynamic>) return null;
      if (source['kind'] != 'emby') return null;

      final base = source['base']?.toString() ?? '';
      final itemId = source['itemId']?.toString() ?? '';
      if (base.isEmpty || itemId.isEmpty) return null;
      return EmbyMediaSource(baseUrl: base, itemId: itemId);
    } catch (_) {
      return null;
    }
  }

  /// Builds a resolver-ready [Media] for playing a single [episode], inheriting
  /// the parent [show]'s source (SMB/WebDAV/local) but pointing at the episode
  /// file. Without this, network episodes would expose a non-playable id URI.
  static Media episodePlayableMedia(Episode episode, Media show) {
    final smb = smbSourceFor(show);
    if (smb != null) {
      return Media(
        id: episode.id,
        title: episode.title,
        year: '',
        type: MediaType.unknown,
        path: episode.path,
        fullPath: episode.fullPath,
        detailsJson: jsonEncode({
          'source': {
            'kind': 'smb',
            'host': smb.host,
            'path': episode.fullPath ?? episode.path,
            'share': smb.share,
            'domain': smb.domain,
            'username': smb.username,
          },
        }),
      );
    }

    final dav = webDavSourceFor(show);
    if (dav != null) {
      return Media(
        id: episode.id,
        title: episode.title,
        year: '',
        type: MediaType.unknown,
        path: episode.path,
        fullPath: episode.fullPath,
        detailsJson: jsonEncode({
          'source': {
            'kind': 'webdav',
            'base': dav.baseUrl,
            'path': episode.fullPath ?? episode.path,
          },
        }),
      );
    }

    final emby = embySourceFor(show);
    if (emby != null) {
      return Media(
        id: episode.id,
        title: episode.title,
        year: '',
        type: MediaType.unknown,
        path: episode.path,
        fullPath: episode.fullPath,
        detailsJson: jsonEncode({
          'source': {
            'kind': 'emby',
            'base': emby.baseUrl,
            'itemId': episode.fullPath ?? episode.path,
          },
        }),
      );
    }

    // Local episode: path/fullPath are directly playable.
    return Media(
      id: episode.id,
      title: episode.title,
      year: '',
      type: MediaType.unknown,
      path: episode.path,
      fullPath: episode.fullPath,
    );
  }

  // --- Private helpers ---

  static Episode? _parseEpisode({
    required String id,
    required String showId,
    required String logicalPath,
    required String basename,
    required String filePath,
    required String fullPath,
  }) {
    final match =
        _episodePattern.firstMatch(basename) ??
        _episodePattern.firstMatch(logicalPath);
    if (match == null) {
      // Check if we can infer season from folder structure
      final seasonNum = _inferSeasonFromPath(logicalPath);
      if (seasonNum != null) {
        return Episode(
          id: id,
          showId: showId,
          seasonNumber: seasonNum,
          episodeNumber: 0,
          title: _cleanTitle(basename),
          path: filePath,
          fullPath: fullPath,
        );
      }
      return null;
    }

    final seasonNum = int.parse(match.group(1)!);
    final episodeNum = int.parse(match.group(2)!);
    final episodeTitle = _episodeTitleFromBasename(basename);

    return Episode(
      id: id,
      showId: showId,
      seasonNumber: seasonNum,
      episodeNumber: episodeNum,
      title: episodeTitle,
      path: filePath,
      fullPath: fullPath,
    );
  }

  static int? _inferSeasonFromPath(String logicalPath) {
    final segments = logicalPath.split('/');
    // Prefer explicit Sxx / Season N tokens, including "S01.第一季".
    final numericSeason = RegExp(
      r'(?:^|[^a-z0-9])s(\d{1,2})(?:$|[^a-z0-9e])|season\s*(\d+)|第(\d+)季',
      caseSensitive: false,
    );
    final chineseSeason = RegExp(r'第([一二三四五六七八九十百]+)季');

    for (final segment in segments) {
      final match = numericSeason.firstMatch(segment);
      if (match != null) {
        final n = match.group(1) ?? match.group(2) ?? match.group(3);
        if (n != null) {
          final parsed = int.tryParse(n);
          if (parsed != null) return parsed;
        }
      }
      final cMatch = chineseSeason.firstMatch(segment);
      if (cMatch != null) {
        final parsed = _chineseNumeral(cMatch.group(1)!);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static int? _chineseNumeral(String s) {
    const map = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
    };
    if (map.containsKey(s)) return map[s];
    // Handle 十一 = 11, 十二 = 12, etc.
    if (s.startsWith('十') && s.length == 2) {
      return 10 + (map[s[1]] ?? 0);
    }
    if (s == '十') return 10;
    return int.tryParse(s);
  }

  static String _episodeTitleFromBasename(String basename) {
    // Remove the S01E02 pattern and clean what remains
    var title = basename.replaceAll(_episodePattern, '');
    title = title.replaceAll(_yearPattern, '');
    title = title.replaceAll(_cleanupPattern, '');
    title = title.replaceAll(RegExp(r'[._\-]+'), ' ');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title;
  }

  static String _tvShowId(String title) => 'tv:${_tvSlug(title)}';

  static String _sourceScopedTvShowId(
    String kind,
    String sourceScope,
    String title,
  ) {
    final encodedScope = base64Url
        .encode(utf8.encode(sourceScope))
        .replaceAll('=', '');
    return 'tv:$kind:$encodedScope:${_tvSlug(title)}';
  }

  static String _tvSlug(String title) {
    // Keep CJK characters and alphanumeric, replace everything else with dashes.
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\u4e00-\u9fff\u3400-\u4dbfa-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String _tvShowDirectory(String filePath) {
    // Walk up from the file to find the show directory (parent of Season folder
    // or parent of the file if no season folder exists).
    final dir = path.dirname(filePath);
    final dirName = path.basename(dir);
    if (_isSeasonFolderName(dirName)) {
      return path.dirname(dir);
    }
    // Handle folders like "怪奇物语 第一季" — the show dir is the same folder
    // but with the season suffix stripped.
    final stripped = _stripSeasonSuffix(dirName);
    if (stripped != dirName && stripped.isNotEmpty) {
      return dir; // This folder IS the show (just named with season)
    }
    return dir;
  }

  static String _tvShowDirectoryFromPath(String logicalPath) {
    final segments = logicalPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    for (var i = 0; i < segments.length; i++) {
      if (_isSeasonFolderName(segments[i]) && i > 0) {
        return segments.sublist(0, i).join('/');
      }
    }
    // Fallback: parent of file
    if (segments.length >= 2) {
      return segments.sublist(0, segments.length - 1).join('/');
    }
    return logicalPath;
  }

  /// Whether [name] is a pure season container directory.
  static bool _isSeasonFolderName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (_seasonPattern.hasMatch(trimmed)) return true;
    // After stripping season markers nothing meaningful remains → season only.
    final stripped = _stripSeasonSuffix(trimmed);
    return stripped.isEmpty || _seasonOnlyTitlePattern.hasMatch(stripped);
  }

  static String _logicalPath(String rawPath) {
    return rawPath.replaceAll('\\', '/');
  }

  static String _ensureLeadingSlash(String rawPath) {
    return rawPath.startsWith('/') ? rawPath : '/$rawPath';
  }

  static MediaType _detectType(String logicalPath, String basename) {
    final lower = logicalPath.toLowerCase();
    if (_episodePattern.hasMatch(basename) ||
        lower.contains('/tv/') ||
        lower.contains('/shows/') ||
        lower.contains('/series/') ||
        lower.contains('/season ') ||
        lower.contains('/season') ||
        _pathHasSeasonFolder(logicalPath) ||
        _looksLikeSeasonPackFolder(logicalPath)) {
      return MediaType.tv;
    }
    if (lower.contains('/movie/') || lower.contains('/movies/')) {
      return MediaType.movie;
    }
    return MediaType.movie;
  }

  static bool _pathHasSeasonFolder(String logicalPath) {
    return logicalPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .any(_isSeasonFolderName);
  }

  /// Paths like `…/生活大爆炸 1-10 季/…` or `…/Show 全4季/…`.
  static bool _looksLikeSeasonPackFolder(String logicalPath) {
    return RegExp(
      r'(?:\d+\s*[-~到至]\s*\d+\s*季|全[一二三四五六七八九十百\d]+\s*季|第[一二三四五六七八九十百\d]+季)',
      caseSensitive: false,
    ).hasMatch(logicalPath);
  }

  static String _titleFor(
    MediaType type,
    String logicalPath,
    String fallbackBasename,
  ) {
    return switch (type) {
      MediaType.tv => _extractTvTitle(logicalPath, fallbackBasename),
      MediaType.movie || MediaType.unknown => _cleanTitle(fallbackBasename),
    };
  }

  static String _extractTvTitle(String logicalPath, String fallback) {
    final segmentList = logicalPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    // Strategy 1: Find a pure season folder (S01.第一季 / Season 1 / 第一季) —
    // the parent of that folder is the show root.
    for (var i = 0; i < segmentList.length; i++) {
      if (!_isSeasonFolderName(segmentList[i]) || i == 0) continue;
      final candidate = _cleanTitle(_stripSeasonSuffix(segmentList[i - 1]));
      if (_isUsableShowTitle(candidate)) return candidate;
    }

    // Strategy 2: Parent folder carries a season suffix
    // ("怪奇物语 第一季") — strip it. If that empties the name, walk higher.
    if (segmentList.length >= 2) {
      for (var offset = 2; offset <= segmentList.length; offset++) {
        final dir = segmentList[segmentList.length - offset];
        if (_isSeasonFolderName(dir)) continue;
        final stripped = _stripSeasonSuffix(dir);
        final candidate = _cleanTitle(stripped);
        if (_isUsableShowTitle(candidate)) return candidate;
      }
    }

    // Strategy 3: Show title embedded in the filename before SxxExx.
    final match = _showTitleFromFilenamePattern.firstMatch(fallback);
    if (match != null) {
      final candidate = _cleanTitle(match.group(1)!);
      if (_isUsableShowTitle(candidate)) return candidate;
    }

    // Fallback: nearest non-season parent folder.
    for (var i = segmentList.length - 2; i >= 0; i--) {
      final candidate = _cleanTitle(_stripSeasonSuffix(segmentList[i]));
      if (_isUsableShowTitle(candidate)) return candidate;
    }
    final fallbackTitle = _cleanTitle(fallback);
    return _isUsableShowTitle(fallbackTitle) ? fallbackTitle : fallbackTitle;
  }

  static bool _isUsableShowTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;
    if (_seasonOnlyTitlePattern.hasMatch(trimmed)) return false;
    // Reject titles that are only punctuation / digits left after cleanup.
    if (RegExp(r'^[\d\s.\-_]+$').hasMatch(trimmed)) return false;
    return true;
  }

  /// Strips trailing / embedded season markers from a folder name to recover
  /// the base show title. Handles:
  /// - "第一季", "第2季", "S01", "Season 1"
  /// - "S01.第一季" style pure season folders (becomes empty)
  /// - "1-4季", "1-10 季", "全4季" collection markers
  /// - "Show 第一季 (2015)" (year parentheses do not block stripping)
  static String _stripSeasonSuffix(String name) {
    var result = name.trim();

    // Pure season containers collapse to empty so callers walk up a level.
    if (_seasonPattern.hasMatch(result)) return '';

    // Drop trailing year tokens first so season markers become terminal.
    // "The Expanse 第一季 (2015)" → "The Expanse 第一季"
    result = result.replaceAll(
      RegExp(r'[\s._\-]*[\(\[]?\s*(?:19|20)\d{2}\s*[\)\]]?\s*$'),
      '',
    );

    // Collection markers: "1-4季", "1-10 季", "1~12季", "1到10季"
    result = result.replaceAll(
      RegExp(r'\s*\d+\s*[-~到至]\s*\d+\s*季\s*$'),
      '',
    );
    result = result.replaceAll(RegExp(r'\s*[\d\-~]+季\s*$'), '');
    result = result.replaceAll(
      RegExp(r'\s*全[一二三四五六七八九十百\d]+\s*季\s*$'),
      '',
    );

    // Trailing single-season markers, with optional leading separators.
    result = result.replaceAll(
      RegExp(
        r'[\s._\-]*('
        r'第[一二三四五六七八九十百\d]+季'
        r'|season\s*\d+'
        r'|s\d{1,2}'
        r')\s*$',
        caseSensitive: false,
      ),
      '',
    );

    // Leading season tokens left over from "S01.Show Name" (rare).
    result = result.replaceAll(
      RegExp(r'^s\d{1,2}[\s._\-]+', caseSensitive: false),
      '',
    );

    return result.trim();
  }

  static String _extractYear(String text) {
    final match = _yearPattern.firstMatch(text);
    return match?.group(0) ?? '';
  }

  static String _cleanTitle(String raw) {
    var title = raw.replaceAll(RegExp(r'[._]+'), ' ');
    title = title.replaceAll(_episodePattern, '');
    title = title.replaceAll(_yearPattern, '');
    title = title.replaceAll(RegExp(r'[\(\)\[\]-]'), ' ');
    title = title.replaceAll(_cleanupPattern, '');
    title = title.replaceAll(_cjkCleanupPattern, '');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title.isEmpty ? raw : title;
  }
}
