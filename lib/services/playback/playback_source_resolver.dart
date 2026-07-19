import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/models/media.dart';
import '../emby/emby_service.dart';
import '../library/media_library_entry_factory.dart';
import 'external_subtitle_finder.dart';
import 'subtitle_text_normalizer.dart';
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
    this.smbConfig,
    this.webDavConfig,
    this.webDav,
    this.emby,
    this.embyConfig,
  });

  final SmbService _smb;
  final SmbProxyServer _proxy;

  /// Looks up stored SMB credentials at playback time so a cold start can
  /// re-establish the session without forcing the user through the browser UI.
  final SmbConfig? Function()? smbConfig;

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
      final playPath = _normalizeSmbPlayPath(smbSource.path);

      // Prefer a mounted local path when the same share is already on disk
      // (common on macOS Finder mounts). Avoids HTTP-proxy + MKV index issues.
      final localPath = _localMountPathIfExists(smbSource, playPath);
      if (localPath != null) {
        final matched = await ExternalSubtitleFinder.findFor(localPath);
        return PlaybackSource(
          localPath,
          subtitles: [
            for (final sub in matched)
              PlaybackSubtitleSource(
                uri: sub.uri,
                title: sub.label,
                language: sub.languageHint,
              ),
          ],
        );
      }

      await _ensureSmbConnected(smbSource);
      await _proxy.start();
      final subtitles = await _findSmbSubtitles(playPath);
      return PlaybackSource(
        _proxy.urlFor(playPath, displayName: p.basename(playPath)),
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

  /// Reconnects to the SMB host required by [source], using stored credentials
  /// after an app restart (mirrors Emby lazy connect).
  Future<void> _ensureSmbConnected(SmbMediaSource source) async {
    final active = _smb.config;
    if (_smb.isConnected &&
        active != null &&
        active.host.toLowerCase() == source.host.toLowerCase()) {
      return;
    }

    final stored = smbConfig?.call();
    if (stored == null || stored.host.trim().isEmpty) {
      throw StateError('SMB source is not connected');
    }

    final host = source.host.isNotEmpty ? source.host : stored.host;
    if (host.isEmpty) {
      throw StateError('SMB source is not connected');
    }
    if (stored.host.toLowerCase() != host.toLowerCase()) {
      // Stored credentials belong to a different NAS — don't silently use them.
      throw StateError(
        'SMB source requires $host, but saved credentials are for ${stored.host}',
      );
    }

    final username = stored.username.isNotEmpty
        ? stored.username
        : (source.username.isNotEmpty ? source.username : 'guest');
    final domain = stored.domain.isNotEmpty ? stored.domain : source.domain;

    try {
      await _smb.connect(
        SmbConfig(
          host: host,
          username: username,
          password: stored.password,
          domain: domain,
        ),
      );
    } catch (error) {
      throw StateError('SMB source is not connected: $error');
    }
  }

  /// Accepts either a share-relative path (`/Movies/x.mkv`) or a full
  /// `smb://host/share/x.mkv` URI and returns the path the proxy/session use.
  static String _normalizeSmbPlayPath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('smb://')) {
      try {
        final uri = Uri.parse(trimmed);
        final path = uri.path;
        return path.startsWith('/') ? path : '/$path';
      } catch (_) {
        final stripped = trimmed.replaceFirst(RegExp(r'^smb://[^/]+'), '');
        return stripped.isEmpty
            ? '/'
            : (stripped.startsWith('/') ? stripped : '/$stripped');
      }
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  /// Maps an SMB path onto a local Finder/OS mount when present, e.g.
  /// `/wd-downloads/foo.mkv` → `/Volumes/wd-downloads/foo.mkv`.
  static String? _localMountPathIfExists(SmbMediaSource source, String playPath) {
    final candidates = <String>[];
    final normalized = playPath.startsWith('/') ? playPath : '/$playPath';
    final share = source.share.trim();

    if (share.isNotEmpty) {
      final sharePrefix = '/$share';
      if (normalized.toLowerCase().startsWith(sharePrefix.toLowerCase())) {
        final rest = normalized.substring(sharePrefix.length);
        candidates.add('/Volumes/$share$rest');
      } else {
        candidates.add('/Volumes/$share$normalized');
      }
    }

    // Path already includes the share as its first segment.
    final parts = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (parts.isNotEmpty) {
      candidates.add('/Volumes/${parts.join('/')}');
    }

    for (final candidate in candidates) {
      try {
        if (File(candidate).existsSync()) return candidate;
      } catch (_) {
        // Ignore unreadable mounts.
      }
    }
    return null;
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
            uri: await _normalizedSmbSubtitleUrl(subtitle.path),
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
            uri: await _normalizedWebDavSubtitleUrl(
              service,
              base,
              subtitle.path,
            ),
            title: subtitle.label,
            language: subtitle.languageHint,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<String> _normalizedSmbSubtitleUrl(String path) async {
    try {
      final length = await _smb.length(path);
      if (length <= 0 || length > 16 * 1024 * 1024) {
        throw const FormatException('Unsupported subtitle size');
      }
      final stream = await _smb.read(path, 0, length - 1);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      final normalized = SubtitleTextNormalizer.toUtf8(builder.takeBytes());
      return _proxy.urlForBytes(normalized, displayName: p.basename(path));
    } catch (_) {
      return _proxy.urlFor(path, displayName: p.basename(path));
    }
  }

  Future<String> _normalizedWebDavSubtitleUrl(
    WebDavService service,
    String base,
    String path,
  ) async {
    try {
      final bytes = await service.readBytes(path);
      if (bytes.isEmpty || bytes.length > 16 * 1024 * 1024) {
        throw const FormatException('Unsupported subtitle size');
      }
      await _proxy.start();
      return _proxy.urlForBytes(
        SubtitleTextNormalizer.toUtf8(bytes),
        displayName: p.basename(path),
      );
    } catch (_) {
      return WebDavService.buildFileUrl(base, path);
    }
  }
}
