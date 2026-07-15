import 'dart:io';

import 'package:path/path.dart' as p;

/// A sidecar subtitle file discovered next to a video.
class ExternalSubtitleFile {
  const ExternalSubtitleFile({
    required this.path,
    required this.label,
    this.languageHint,
  });

  /// Absolute filesystem path to the subtitle file.
  final String path;

  /// Human-readable label for the track picker.
  final String label;

  /// Best-effort language tag derived from the filename (e.g. `zh`, `en`).
  final String? languageHint;

  /// A media_kit-ready URI for either a local file or a network subtitle.
  String get uri {
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) return parsed.toString();
    return Uri.file(path).toString();
  }
}

/// Finds external subtitle files that sit next to a local video.
///
/// Matching rules (basename of the video without extension):
/// - exact: `Movie.srt`, `Movie.ass`
/// - tagged: `Movie.chs.srt`, `Movie.zh-CN.ass`, `Movie.en.srt`
///
/// Network URLs (`http://`, `https://`, `smb://`) are skipped — those need a
/// separate proxy path.
class ExternalSubtitleFinder {
  ExternalSubtitleFinder._();

  static const supportedExtensions = <String>{
    '.srt',
    '.ass',
    '.ssa',
    '.vtt',
    '.sub',
  };

  static final _langTag = RegExp(
    r'\.(chs|cht|zh|zh-cn|zh-tw|zh-hk|chi|cn|tc|sc|en|eng|ja|jp|jpn|ko|kor|fr|de|es|ru)(?:\.|$)',
    caseSensitive: false,
  );

  /// Returns sidecar subtitle files for [mediaUri], sorted with Chinese
  /// variants first, then English, then others.
  static Future<List<ExternalSubtitleFile>> findFor(String mediaUri) async {
    final localPath = _localFilesystemPath(mediaUri);
    if (localPath == null) return const [];

    final video = File(localPath);
    if (!await video.exists()) return const [];

    final dir = video.parent;
    final stem = p.basenameWithoutExtension(video.path).toLowerCase();
    if (stem.isEmpty) return const [];

    final siblingPaths = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      siblingPaths.add(entity.path);
    }
    return findAmongSiblings(video.path, siblingPaths);
  }

  /// Matches subtitle paths already obtained from a local or network directory
  /// listing. The returned [ExternalSubtitleFile.path] values are unchanged so
  /// callers can replace them with proxy or WebDAV URLs afterwards.
  static List<ExternalSubtitleFile> findAmongSiblings(
    String mediaPath,
    Iterable<String> siblingPaths,
  ) {
    final stem = p.basenameWithoutExtension(mediaPath).toLowerCase();
    if (stem.isEmpty) return const [];

    final results = <ExternalSubtitleFile>[];
    for (final siblingPath in siblingPaths) {
      final name = p.basename(siblingPath);
      final ext = p.extension(name).toLowerCase();
      if (!supportedExtensions.contains(ext)) continue;

      final lower = name.toLowerCase();
      final nameStem = p.basenameWithoutExtension(name).toLowerCase();
      // Accept exact stem or stem + language/tags (Movie.chs, Movie.zh-CN).
      if (nameStem != stem && !lower.startsWith('$stem.')) continue;

      final lang = _languageFromName(name);
      results.add(
        ExternalSubtitleFile(
          path: siblingPath,
          label: _labelFor(name, lang),
          languageHint: lang,
        ),
      );
    }

    results.sort((a, b) {
      final rank = _langRank(
        a.languageHint,
      ).compareTo(_langRank(b.languageHint));
      if (rank != 0) return rank;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return results;
  }

  /// Returns a filesystem path for local media, or null for network URLs.
  static String? _localFilesystemPath(String uri) {
    final lower = uri.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('smb://')) {
      return null;
    }
    if (lower.startsWith('file://')) {
      return Uri.parse(uri).toFilePath();
    }
    return uri.isEmpty ? null : uri;
  }

  static String? _languageFromName(String name) {
    final match = _langTag.firstMatch(name);
    if (match == null) return null;
    return match.group(1)?.toLowerCase();
  }

  static String _labelFor(String fileName, String? lang) {
    final langLabel = switch (lang) {
      'chs' || 'zh' || 'zh-cn' || 'chi' || 'cn' || 'sc' => '简体中文',
      'cht' || 'zh-tw' || 'zh-hk' || 'tc' => '繁体中文',
      'en' || 'eng' => 'English',
      'ja' || 'jp' || 'jpn' => '日本語',
      'ko' || 'kor' => '한국어',
      null => null,
      _ => lang,
    };
    if (langLabel == null) return '外挂 · $fileName';
    return '外挂 · $langLabel ($fileName)';
  }

  static int _langRank(String? lang) {
    return switch (lang) {
      'chs' || 'zh' || 'zh-cn' || 'chi' || 'cn' || 'sc' => 0,
      'cht' || 'zh-tw' || 'zh-hk' || 'tc' => 1,
      'en' || 'eng' => 2,
      null => 50,
      _ => 10,
    };
  }

  /// Whether [hint] looks like a Chinese language tag (for auto-select).
  static bool isChineseHint(String? hint) {
    if (hint == null) return false;
    final h = hint.toLowerCase();
    return h.contains('zh') ||
        h.contains('chi') ||
        h == 'chs' ||
        h == 'cht' ||
        h == 'cn' ||
        h == 'sc' ||
        h == 'tc';
  }
}
