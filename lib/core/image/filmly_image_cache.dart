import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Long-lived disk cache for posters / backdrops / cast photos.
///
/// Default [DefaultCacheManager] only keeps ~200 objects for 30 days, which is
/// far too small for a media library — posters get evicted and re-download on
/// every cold start. This manager keeps thousands of images for a year.
class FilmlyImageCache {
  FilmlyImageCache._();

  static const key = 'openFilmlyImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 8000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// Resolve a stored poster/backdrop path (absolute URL, local file, or TMDB
  /// relative `/abc.jpg`) into a network URL when possible.
  static String? networkUrl(
    String? path, {
    TmdbImageSize size = TmdbImageSize.w500,
  }) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return 'https://image.tmdb.org/t/p/${size.pathSegment}$value';
    }
    return null;
  }

  /// Warm the disk cache for a list of image URLs (best-effort, fire-and-forget).
  static Future<void> precacheUrls(Iterable<String?> urls) async {
    for (final raw in urls) {
      final url = raw?.trim();
      if (url == null || url.isEmpty) continue;
      if (!url.startsWith('http://') && !url.startsWith('https://')) continue;
      try {
        await instance.downloadFile(url);
      } catch (_) {
        // Network / TMDB blips are fine — UI still falls back to placeholder.
      }
    }
  }

  static Future<void> emptyCache() => instance.emptyCache();
}

enum TmdbImageSize {
  w185('w185'),
  w342('w342'),
  w500('w500'),
  w780('w780'),
  w1280('w1280'),
  original('original');

  const TmdbImageSize(this.pathSegment);
  final String pathSegment;
}

/// Drop-in [CachedNetworkImage] that always hits [FilmlyImageCache] and skips
/// the fade-in when the file is already on disk (instant cold-start paint).
class FilmlyNetworkImage extends StatelessWidget {
  const FilmlyNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: FilmlyImageCache.instance,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      // Cached hits should paint immediately; only network loads fade in.
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: Duration.zero,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
