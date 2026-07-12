import 'package:path/path.dart' as p;

import '../../data/models/media.dart';
import '../emby/emby_service.dart';
import '../library/media_library_entry_factory.dart';
import 'external_subtitle_finder.dart';
import '../smb/smb_proxy_server.dart';
import '../smb/smb_service.dart';
import '../webdav/webdav_service.dart';

/// A player-ready source: a URI the native player can open, plus optional HTTP headers
/// (used for WebDAV Basic auth).
class PlaybackSubtitleSource {
  const PlaybackSubtitleSource({
    required this.uri,
    required this.title,
    this.language,
  });

  final String uri;
  final String title;
  final String? language;
}

class PlaybackSource {
  const PlaybackSource(this.uri, {this.httpHeaders, this.subtitles = const []});

  final String uri;
  final Map<String, String>? httpHeaders;
  final List<PlaybackSubtitleSource> subtitles;
}

/// Resolves a library item into a [PlaybackSource] that the native player can open.
class PlaybackSourceResolver {
  PlaybackSourceResolver(
    this._smb,
    this._proxy, {
    this.webDavConfig,
    this.webDav,
    this.emby,
    this.embyConfig,
  });

  final SmbService _smb;
  final SmbProxyServer _proxy;

  /// Looks up the current WebDAV credentials at playback time (may be null).
  final WebDavConfig? Function()? webDavConfig;
  final WebDavService? webDav;

  /// The live Emby session, used to build authed stream URLs (may be null).
  final EmbyService? emby;

  /// Looks up Emby credentials so the session can be re-established lazily
  /// (e.g. after an app restart) before resolving an Emby item.
  final EmbyConfig? Function()? embyConfig;

  Future<PlaybackSource> resolve(Media media) async {
    final smbSource = MediaLibraryEntryFactory.smbSourceFor(media);
    if (smbSource != null) {
      final config = _smb.config;
      if (!_smb.isConnected || config == null) {
        throw StateError('SMB source is not connected');
      }
      if (config.host.toLowerCase() != smbSource.host.toLowerCase()) {
        throw StateError(
          'SMB source requires ${smbSource.host}, but the current connection is ${config.host}',
        );
      }
      await _proxy.start();
      final subtitles = await _findSmbSubtitles(smbSource.path);
      return PlaybackSource(
        _proxy.urlFor(smbSource.path, displayName: p.basename(smbSource.path)),
        subtitles: subtitles,
      );
    }

    final webDavSource = MediaLibraryEntryFactory.webDavSourceFor(media);
    if (webDavSource != null) {
      final config = webDavConfig?.call();
      // Prefer the live config's base + credentials; fall back to the stored
      // base URL (e.g. credentials cleared, or playing from a cached entry).
      final base = (config != null && config.url.isNotEmpty)
          ? config.url
          : webDavSource.baseUrl;
      final url = WebDavService.buildFileUrl(base, webDavSource.path);
      final headers = config?.authHeaders;
      final subtitles = await _findWebDavSubtitles(
        base: base,
        mediaPath: webDavSource.path,
        config: config,
      );
      return PlaybackSource(
        url,
        httpHeaders: (headers != null && headers.isNotEmpty) ? headers : null,
        subtitles: subtitles,
      );
    }

    final embySource = MediaLibraryEntryFactory.embySourceFor(media);
    if (embySource != null) {
      final session = emby;
      if (session == null) {
        throw StateError('Emby source is not available');
      }
      // Re-establish the session after a restart if we have stored credentials.
      if (!session.isConnected) {
        final config = embyConfig?.call();
        if (config == null || !config.isComplete) {
          throw StateError('Emby source is not connected');
        }
        await session.connect(config);
      }
      // The token lives in the active session; embed it in the stream URL.
      return PlaybackSource(session.streamUrl(embySource.itemId));
    }

    final fullPath = media.fullPath;
    if (fullPath != null && fullPath.isNotEmpty) {
      return PlaybackSource(fullPath);
    }
    if (media.path.isNotEmpty) {
      return PlaybackSource(media.path);
    }
    throw StateError('No playable source available for this media item');
  }

  Future<List<PlaybackSubtitleSource>> _findSmbSubtitles(
    String mediaPath,
  ) async {
    try {
      final entries = await _smb.listChildrenByPath(p.posix.dirname(mediaPath));
      final matched = ExternalSubtitleFinder.findAmongSiblings(
        mediaPath,
        entries
            .where((entry) => !entry.isDirectory())
            .map((entry) => entry.path),
      );
      return [
        for (final subtitle in matched)
          PlaybackSubtitleSource(
            uri: _proxy.urlFor(
              subtitle.path,
              displayName: p.basename(subtitle.path),
            ),
            title: subtitle.label,
            language: subtitle.languageHint,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<PlaybackSubtitleSource>> _findWebDavSubtitles({
    required String base,
    required String mediaPath,
    required WebDavConfig? config,
  }) async {
    final service = webDav;
    if (service == null || config == null) return const [];
    try {
      final active = service.config;
      if (!service.isConnected ||
          active?.url != config.url ||
          active?.username != config.username ||
          active?.password != config.password) {
        await service.connect(config);
      }
      final entries = await service.listDir(p.posix.dirname(mediaPath));
      final matched = ExternalSubtitleFinder.findAmongSiblings(
        mediaPath,
        entries.where((entry) => !entry.isDir).map((entry) => entry.path),
      );
      return [
        for (final subtitle in matched)
          PlaybackSubtitleSource(
            uri: WebDavService.buildFileUrl(base, subtitle.path),
            title: subtitle.label,
            language: subtitle.languageHint,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}
