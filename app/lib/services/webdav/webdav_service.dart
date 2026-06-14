import 'dart:convert';

import 'package:webdav_client/webdav_client.dart' as webdav;

/// WebDAV connection parameters.
class WebDavConfig {
  const WebDavConfig({
    required this.url,
    this.username = '',
    this.password = '',
  });

  /// Base URL of the WebDAV endpoint, e.g. `https://dav.example.com/dav`.
  final String url;
  final String username;
  final String password;

  bool get isComplete => url.trim().isNotEmpty;

  /// HTTP Basic auth header value, or null when no credentials are set.
  String? get basicAuthHeader {
    if (username.isEmpty && password.isEmpty) return null;
    final token = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $token';
  }

  /// Auth headers suitable for handing to the native player / an HTTP client.
  Map<String, String> get authHeaders {
    final header = basicAuthHeader;
    return header == null ? const {} : {'Authorization': header};
  }
}

/// A directory entry returned while browsing a WebDAV server.
class WebDavEntry {
  const WebDavEntry({
    required this.name,
    required this.path,
    required this.isDir,
    this.size,
  });

  final String name;
  final String path;
  final bool isDir;
  final int? size;
}

/// Wraps a [webdav.Client] session: connection test plus directory browsing.
///
/// WebDAV is plain HTTP(S), so unlike SMB it needs no local proxy — the player
/// can stream the file URL directly with a Basic-auth header. This service is
/// therefore only responsible for connect + browse; URL building lives in
/// [fileUrl].
class WebDavService {
  WebDavConfig? _config;
  webdav.Client? _client;

  bool get isConnected => _client != null;
  WebDavConfig? get config => _config;

  /// Connects and verifies the server is reachable. Throws on failure.
  Future<void> connect(WebDavConfig config) async {
    final client = webdav.newClient(
      _normalizeBase(config.url),
      user: config.username,
      password: config.password,
    );
    client.setConnectTimeout(15000);
    await client.ping();
    _client = client;
    _config = config;
  }

  /// Lists the children of [dirPath] (defaults to the server root).
  Future<List<WebDavEntry>> listDir([String dirPath = '/']) async {
    final files = await _conn.readDir(dirPath);
    return files
        .map(
          (f) => WebDavEntry(
            name: f.name ?? '',
            path: f.path ?? '',
            isDir: f.isDir ?? false,
            size: f.size,
          ),
        )
        .where((e) => e.name.isNotEmpty)
        .toList(growable: false);
  }

  /// Builds the absolute, encoded URL for a file [relativePath] on this server.
  String fileUrl(String relativePath) {
    final config = _config;
    if (config == null) {
      throw StateError('WebDAV connection not established');
    }
    return buildFileUrl(config.url, relativePath);
  }

  void disconnect() {
    _client = null;
    _config = null;
  }

  webdav.Client get _conn {
    final client = _client;
    if (client == null) {
      throw StateError('WebDAV connection not established');
    }
    return client;
  }

  /// Joins a WebDAV base URL with a server-relative path, percent-encoding each
  /// path segment so spaces and CJK characters stream correctly.
  static String buildFileUrl(String baseUrl, String relativePath) {
    final base = _normalizeBase(baseUrl);
    final baseUri = Uri.parse(base);

    final segments = relativePath
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.encodeComponent)
        .toList(growable: false);

    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;

    return baseUri.replace(path: '$basePath/${segments.join('/')}').toString();
  }

  static String _normalizeBase(String url) {
    var result = url.trim();
    if (!result.startsWith('http://') && !result.startsWith('https://')) {
      result = 'https://$result';
    }
    return result;
  }
}
