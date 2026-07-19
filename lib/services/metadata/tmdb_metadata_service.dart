import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/formatters/rating_formatter.dart';
import '../../data/models/media.dart';
import '../library/media_library_entry_factory.dart';

class TmdbMetadataPayload {
  const TmdbMetadataPayload({
    required this.title,
    required this.year,
    required this.type,
    required this.posterPath,
    required this.rating,
    required this.detailsJson,
  });

  final String title;
  final String year;
  final MediaType type;
  final String? posterPath;
  final String? rating;
  final String detailsJson;
}

/// 手动搜索结果项，封装基本的海报墙元数据
class TmdbSearchResult {
  const TmdbSearchResult({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.releaseDate,
    required this.type,
  });

  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String releaseDate;
  final MediaType type;
}

/// Per-episode metadata fetched on demand from TMDB.
class TmdbEpisodeDetails {
  const TmdbEpisodeDetails({
    required this.name,
    required this.overview,
    required this.stillUrl,
    required this.airDate,
    required this.rating,
  });

  final String name;
  final String overview;
  final String? stillUrl;
  final String airDate;
  final String? rating;
}

/// One cast member from TMDB credits (for the 相关演员 row).
class TmdbCastMember {
  const TmdbCastMember({
    required this.name,
    required this.character,
    required this.profileUrl,
  });

  final String name;
  final String character;
  final String? profileUrl;
}

/// Thin TMDB client for search + details lookups.
class TmdbMetadataService {
  TmdbMetadataService(
    this._client, {
    Uri? baseUri,
    this.imageBaseUrl = 'https://image.tmdb.org/t/p',
  }) : baseUri = baseUri ?? Uri.parse('https://api.themoviedb.org/3');

  final http.Client _client;
  final Uri baseUri;
  final String imageBaseUrl;

  /// Fetch metadata from TMDB. If [searchTitle] is provided (e.g. from AI
  /// recognition), it's used instead of media.title for the TMDB query.
  Future<TmdbMetadataPayload?> fetchMetadata(
    Media media,
    String apiKey, {
    String? searchTitle,
    String? searchYear,
  }) async {
    final searchTypes = switch (media.type) {
      MediaType.movie => [MediaType.movie],
      MediaType.tv => [MediaType.tv],
      MediaType.unknown => [MediaType.movie, MediaType.tv],
    };
    final searchTitles = <String>[];
    for (final title in [searchTitle, media.title]) {
      final normalized = title?.trim() ?? '';
      if (normalized.isEmpty) continue;
      final alreadyAdded = searchTitles.any(
        (candidate) => candidate.toLowerCase() == normalized.toLowerCase(),
      );
      if (!alreadyAdded) searchTitles.add(normalized);
    }

    for (final type in searchTypes) {
      for (final title in searchTitles) {
        final searchResult = await _search(
          type,
          media,
          apiKey,
          titleOverride: title,
          yearOverride: searchYear,
        );
        if (searchResult == null) continue;

        final details = await _details(type, searchResult['id'], apiKey);
        if (details == null) continue;

        return _mapPayload(
          media,
          type,
          searchResult: searchResult,
          details: details,
        );
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _search(
    MediaType type,
    Media media,
    String apiKey, {
    String? titleOverride,
    String? yearOverride,
  }) async {
    final endpoint = switch (type) {
      MediaType.movie => '/search/movie',
      MediaType.tv => '/search/tv',
      MediaType.unknown => '/search/multi',
    };
    final searchQuery = titleOverride ?? media.title;
    final year = yearOverride ?? media.year;

    // Determine search languages based on query content:
    // - If query contains non-ASCII (likely Chinese), search zh-CN first
    // - If query is ASCII-only (likely English), search en-US first, then zh-CN
    final hasNonAscii = searchQuery.codeUnits.any((c) => c > 127);
    final searchLanguages = hasNonAscii ? ['zh-CN'] : ['en-US', 'zh-CN'];

    for (final language in searchLanguages) {
      final query = <String, String>{
        'api_key': apiKey,
        'query': searchQuery,
        'language': language,
      };

      if (year.isNotEmpty) {
        if (type == MediaType.movie) {
          query['year'] = year;
        } else if (type == MediaType.tv) {
          query['first_air_date_year'] = year;
        }
      }

      final response = await _client.get(_buildUri(endpoint, query));
      if (response.statusCode != 200) continue;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) continue;
      final results = decoded['results'];
      if (results is! List || results.isEmpty) continue;

      final first = results.first;
      if (first is Map<String, dynamic>) return first;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _details(
    MediaType type,
    Object? id,
    String apiKey,
  ) async {
    if (id == null) return null;

    final endpoint = switch (type) {
      MediaType.movie => '/movie/$id',
      MediaType.tv => '/tv/$id',
      MediaType.unknown => '/movie/$id',
    };

    final response = await _client.get(
      _buildUri(endpoint, {'api_key': apiKey, 'language': 'zh-CN'}),
    );
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// Fetches a single episode's TMDB details (name, overview, still, air date).
  /// Returns null if [tvId] is unknown or the request fails.
  Future<TmdbEpisodeDetails?> fetchEpisodeDetails({
    required Object tvId,
    required int seasonNumber,
    required int episodeNumber,
    required String apiKey,
  }) async {
    final endpoint = '/tv/$tvId/season/$seasonNumber/episode/$episodeNumber';
    final response = await _client.get(
      _buildUri(endpoint, {'api_key': apiKey, 'language': 'zh-CN'}),
    );
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    return _mapEpisode(decoded);
  }

  /// Fetches an entire season's episode list in one request (Chinese titles +
  /// overviews + stills). Keyed by episode_number.
  Future<Map<int, TmdbEpisodeDetails>> fetchSeasonEpisodes({
    required Object tvId,
    required int seasonNumber,
    required String apiKey,
  }) async {
    final endpoint = '/tv/$tvId/season/$seasonNumber';
    final response = await _client.get(
      _buildUri(endpoint, {'api_key': apiKey, 'language': 'zh-CN'}),
    );
    if (response.statusCode != 200) return const {};

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const {};
    final list = decoded['episodes'];
    if (list is! List) return const {};

    final out = <int, TmdbEpisodeDetails>{};
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final n = int.tryParse(item['episode_number']?.toString() ?? '');
      if (n == null) continue;
      out[n] = _mapEpisode(item);
    }
    return out;
  }

  TmdbEpisodeDetails _mapEpisode(Map<String, dynamic> decoded) {
    return TmdbEpisodeDetails(
      name: decoded['name']?.toString() ?? '',
      overview: decoded['overview']?.toString() ?? '',
      stillUrl: _imageUrl(decoded['still_path']),
      airDate: decoded['air_date']?.toString() ?? '',
      rating: formatRating(decoded['vote_average']),
    );
  }

  /// Fetches the top-billed cast for a movie or TV show (the 相关演员 row).
  /// Returns an empty list when the id is unknown or the request fails.
  Future<List<TmdbCastMember>> fetchCredits({
    required Object tmdbId,
    required MediaType type,
    required String apiKey,
    int limit = 12,
  }) async {
    final kind = type == MediaType.tv ? 'tv' : 'movie';
    final response = await _client.get(
      _buildUri('/$kind/$tmdbId/credits', {
        'api_key': apiKey,
        'language': 'zh-CN',
      }),
    );
    if (response.statusCode != 200) return const [];

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final cast = decoded['cast'];
    if (cast is! List) return const [];

    return cast
        .whereType<Map<String, dynamic>>()
        .take(limit)
        .map(
          (c) => TmdbCastMember(
            name: c['name']?.toString() ?? '',
            character: c['character']?.toString() ?? '',
            profileUrl: _imageUrl(c['profile_path']),
          ),
        )
        .where((c) => c.name.isNotEmpty)
        .toList(growable: false);
  }

  TmdbMetadataPayload _mapPayload(
    Media media,
    MediaType type, {
    required Map<String, dynamic> searchResult,
    required Map<String, dynamic> details,
  }) {
    final title = switch (type) {
      MediaType.movie =>
        (details['title'] ?? searchResult['title'] ?? media.title).toString(),
      MediaType.tv =>
        (details['name'] ?? searchResult['name'] ?? media.title).toString(),
      MediaType.unknown => media.title,
    };
    final year = switch (type) {
      MediaType.movie => _extractYear(
        (details['release_date'] ?? searchResult['release_date']).toString(),
      ),
      MediaType.tv => _extractYear(
        (details['first_air_date'] ?? searchResult['first_air_date'])
            .toString(),
      ),
      MediaType.unknown => media.year,
    };
    final posterPath = _imageUrl(
      details['poster_path'] ?? searchResult['poster_path'],
    );
    final ratingValue = details['vote_average'] ?? searchResult['vote_average'];
    final smbSource = MediaLibraryEntryFactory.smbSourceFor(media);
    final webDavSource = MediaLibraryEntryFactory.webDavSourceFor(media);
    final tmdbId = searchResult['id'] ?? details['id'];

    final detailsJson = jsonEncode({
      // Preserve the playback source across re-enrichment (it is rebuilt here).
      if (smbSource != null)
        'source': {
          'kind': 'smb',
          'host': smbSource.host,
          'path': smbSource.path,
          'share': smbSource.share,
          'domain': smbSource.domain,
          'username': smbSource.username,
        }
      else if (webDavSource != null)
        'source': {
          'kind': 'webdav',
          'base': webDavSource.baseUrl,
          'path': webDavSource.path,
        },
      'tmdbId': ?tmdbId,
      'overview': details['overview'] ?? searchResult['overview'],
      'backdrop_path':
          details['backdrop_path'] ?? searchResult['backdrop_path'],
      'release_date': switch (type) {
        MediaType.movie =>
          details['release_date'] ?? searchResult['release_date'],
        MediaType.tv =>
          details['first_air_date'] ?? searchResult['first_air_date'],
        MediaType.unknown => null,
      },
      'genres': _genres(details['genres']),
    });

    return TmdbMetadataPayload(
      title: title,
      year: year.isEmpty ? media.year : year,
      type: type,
      posterPath: posterPath,
      rating: formatRating(ratingValue),
      detailsJson: detailsJson,
    );
  }

  Uri _buildUri(String endpoint, Map<String, String> query) {
    return baseUri.replace(
      path: '${baseUri.path}$endpoint',
      queryParameters: query,
    );
  }

  String _extractYear(String raw) {
    return raw.length >= 4 ? raw.substring(0, 4) : '';
  }

  String? _imageUrl(Object? rawPath) {
    final value = rawPath?.toString();
    if (value == null || value.isEmpty || value == 'null') return null;
    return '$imageBaseUrl/w500$value';
  }

  List<String> _genres(Object? rawGenres) {
    if (rawGenres is! List) return const [];
    return rawGenres
        .map((genre) {
          if (genre is String) return genre;
          if (genre is Map<String, dynamic>) {
            return genre['name']?.toString() ?? '';
          }
          return '';
        })
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  /// 手动搜索 TMDB，返回所有搜索结果（支持全部/电影/电视剧分类筛选）
  Future<List<TmdbSearchResult>> searchAll(
    String query,
    String apiKey, {
    MediaType? type,
  }) async {
    final results = <TmdbSearchResult>[];

    // 决定要检索的类型，若为 unknown 或 null 则电影和电视都搜索
    final typesToSearch = type != null && type != MediaType.unknown
        ? [type]
        : [MediaType.movie, MediaType.tv];

    for (final t in typesToSearch) {
      final endpoint = switch (t) {
        MediaType.movie => '/search/movie',
        MediaType.tv => '/search/tv',
        MediaType.unknown => '/search/multi',
      };

      final hasNonAscii = query.codeUnits.any((c) => c > 127);
      final searchLanguages = hasNonAscii ? ['zh-CN'] : ['en-US', 'zh-CN'];

      for (final language in searchLanguages) {
        final uri = _buildUri(endpoint, {
          'api_key': apiKey,
          'query': query,
          'language': language,
        });

        try {
          final response = await _client.get(uri);
          if (response.statusCode != 200) continue;

          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) continue;
          final rawResults = decoded['results'];
          if (rawResults is! List || rawResults.isEmpty) continue;

          for (final item in rawResults) {
            if (item is! Map<String, dynamic>) continue;
            final id = item['id'] as int?;
            if (id == null) continue;

            final title =
                (t == MediaType.movie
                        ? (item['title'] ?? item['original_title'])
                        : (item['name'] ?? item['original_name']))
                    ?.toString() ??
                '';
            final overview = item['overview']?.toString() ?? '';
            final posterPath = _imageUrl(item['poster_path']);
            final releaseDate =
                (t == MediaType.movie
                        ? item['release_date']
                        : item['first_air_date'])
                    ?.toString() ??
                '';

            // 去重
            if (results.any((r) => r.id == id && r.type == t)) continue;

            results.add(
              TmdbSearchResult(
                id: id,
                title: title,
                overview: overview,
                posterPath: posterPath,
                releaseDate: releaseDate,
                type: t,
              ),
            );
          }
        } catch (_) {
          // 忽略单个请求异常
        }
      }
    }

    // 排序：有海报的排在前面，若都有则按发行日期降序排序
    results.sort((a, b) {
      if (a.posterPath != null && b.posterPath == null) return -1;
      if (a.posterPath == null && b.posterPath != null) return 1;
      return b.releaseDate.compareTo(a.releaseDate);
    });

    return results;
  }

  /// 使用指定的 TMDB ID 和类型拉取详情，生成 metadata payload
  Future<TmdbMetadataPayload?> fetchDetails(
    Media media,
    int tmdbId,
    MediaType type,
    String apiKey,
  ) async {
    final details = await _details(type, tmdbId, apiKey);
    if (details == null) return null;

    final searchResult = {
      'id': tmdbId,
      'title': details['title'] ?? details['name'],
      'name': details['name'] ?? details['title'],
      'poster_path': details['poster_path'],
      'backdrop_path': details['backdrop_path'],
      'release_date': details['release_date'] ?? details['first_air_date'],
      'first_air_date': details['first_air_date'] ?? details['release_date'],
      'overview': details['overview'],
      'vote_average': details['vote_average'],
    };

    return _mapPayload(
      media,
      type,
      searchResult: searchResult,
      details: details,
    );
  }
}
