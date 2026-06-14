import 'dart:convert';

import 'package:http/http.dart' as http;

/// Emby / Jellyfin connection parameters.
class EmbyConfig {
  const EmbyConfig({required this.url, this.username = '', this.password = ''});

  /// Server base URL, e.g. `http://192.168.1.10:8096`.
  final String url;
  final String username;
  final String password;

  bool get isComplete => url.trim().isNotEmpty;
}

/// A media item returned from an Emby/Jellyfin library.
class EmbyItem {
  const EmbyItem({
    required this.id,
    required this.name,
    required this.type,
    required this.year,
    this.primaryImageTag,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
    this.overview,
  });

  final String id;
  final String name;

  /// Raw Emby item type: `Movie`, `Series`, or `Episode`.
  final String type;
  final String year;
  final String? primaryImageTag;
  final String? seriesId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? overview;
}

/// Thin Emby/Jellyfin REST client: authenticate, list libraries, and build
/// stream / image URLs. Both servers share the same core API surface, so one
/// client covers them. The access token is embedded as an `api_key` query
/// param on stream/image URLs, so the player and the image loader need no extra
/// headers.
class EmbyService {
  EmbyService(this._client);

  final http.Client _client;

  EmbyConfig? _config;
  String? _baseUrl;
  String? _token;
  String? _userId;

  static const _clientName = 'OpenFilmly';
  static const _deviceId = 'open-filmly-flutter';
  static const _version = '1.0.0';

  bool get isConnected => _token != null && _baseUrl != null;
  EmbyConfig? get config => _config;
  String? get accessToken => _token;

  String get _authHeader =>
      'MediaBrowser Client="$_clientName", Device="$_clientName", '
      'DeviceId="$_deviceId", Version="$_version"';

  /// Authenticates against the server and stores the session token.
  Future<void> connect(EmbyConfig config) async {
    final base = _normalizeBase(config.url);
    final uri = Uri.parse('$base/Users/AuthenticateByName');

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Emby-Authorization': _authHeader,
      },
      body: jsonEncode({'Username': config.username, 'Pw': config.password}),
    );

    if (response.statusCode != 200) {
      throw StateError('认证失败（HTTP ${response.statusCode}）');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('服务器返回了无法解析的响应');
    }
    final token = decoded['AccessToken']?.toString();
    final user = decoded['User'];
    final userId = user is Map<String, dynamic> ? user['Id']?.toString() : null;
    if (token == null || token.isEmpty || userId == null) {
      throw StateError('认证响应缺少令牌');
    }

    _config = config;
    _baseUrl = base;
    _token = token;
    _userId = userId;
  }

  /// Lists all movies and series in the user's libraries.
  Future<List<EmbyItem>> fetchLibrary() async {
    final items = await _getItems('/Users/$_userId/Items', {
      'Recursive': 'true',
      'IncludeItemTypes': 'Movie,Series',
      'Fields': 'ProductionYear,Overview',
      'SortBy': 'SortName',
      'SortOrder': 'Ascending',
    });
    return items;
  }

  /// Lists episodes of a series (used to populate TV show detail).
  Future<List<EmbyItem>> fetchEpisodes(String seriesId) async {
    return _getItems('/Shows/$seriesId/Episodes', {
      'UserId': _userId ?? '',
      'Fields': 'Overview,ProductionYear',
    });
  }

  Future<List<EmbyItem>> _getItems(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse(
      '${_requireBase()}$path',
    ).replace(queryParameters: {...query, 'api_key': _requireToken()});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw StateError('读取媒体库失败（HTTP ${response.statusCode}）');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final rawItems = decoded['Items'];
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(_toItem)
        .toList(growable: false);
  }

  EmbyItem _toItem(Map<String, dynamic> json) {
    final imageTags = json['ImageTags'];
    final primaryTag = imageTags is Map<String, dynamic>
        ? imageTags['Primary']?.toString()
        : null;
    return EmbyItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      type: json['Type']?.toString() ?? '',
      year: json['ProductionYear']?.toString() ?? '',
      primaryImageTag: primaryTag,
      seriesId: json['SeriesId']?.toString(),
      seasonNumber: (json['ParentIndexNumber'] as num?)?.toInt(),
      episodeNumber: (json['IndexNumber'] as num?)?.toInt(),
      overview: json['Overview']?.toString(),
    );
  }

  /// Direct-stream URL for an item, with the access token embedded.
  String streamUrl(String itemId) {
    return '${_requireBase()}/Videos/$itemId/stream'
        '?static=true&api_key=${_requireToken()}';
  }

  /// Primary poster image URL for an item, with the access token embedded.
  String imageUrl(String itemId, {String? tag}) {
    final base =
        '${_requireBase()}/Items/$itemId/Images/Primary'
        '?api_key=${_requireToken()}';
    return tag == null ? base : '$base&tag=$tag';
  }

  /// Builds a stream URL from a base + token captured at import time. Used by
  /// the playback resolver, which may re-auth and supply a fresh token.
  static String buildStreamUrl(String baseUrl, String itemId, String token) {
    return '${_normalizeBase(baseUrl)}/Videos/$itemId/stream'
        '?static=true&api_key=$token';
  }

  void disconnect() {
    _config = null;
    _baseUrl = null;
    _token = null;
    _userId = null;
  }

  String _requireBase() {
    final base = _baseUrl;
    if (base == null) throw StateError('Emby 未连接');
    return base;
  }

  String _requireToken() {
    final token = _token;
    if (token == null) throw StateError('Emby 未连接');
    return token;
  }

  static String _normalizeBase(String url) {
    var result = url.trim();
    if (!result.startsWith('http://') && !result.startsWith('https://')) {
      result = 'http://$result';
    }
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
