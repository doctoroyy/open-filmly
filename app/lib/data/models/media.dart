import 'dart:convert';

enum MediaType {
  movie,
  tv,
  unknown;

  static MediaType fromString(String? value) {
    switch (value) {
      case 'movie':
        return MediaType.movie;
      case 'tv':
        return MediaType.tv;
      default:
        return MediaType.unknown;
    }
  }

  String get value => name;
}

/// Domain model for a library item (movie or TV show).
///
/// Convenience metadata fields (overview/genres/...) are parsed leniently from
/// the stored `details` JSON; the raw JSON is kept in [detailsJson] so writes
/// don't lose fields this model doesn't surface.
class Media {
  const Media({
    required this.id,
    required this.title,
    required this.year,
    required this.type,
    required this.path,
    this.fullPath,
    this.posterPath,
    this.rating,
    this.detailsJson,
    this.overview,
    this.backdropPath,
    this.releaseDate,
    this.genres = const [],
    this.fileHash,
    this.dateAdded = '',
    this.lastUpdated = '',
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String year;
  final MediaType type;
  final String path;
  final String? fullPath;
  final String? posterPath;
  final String? rating;
  final String? detailsJson;
  final String? overview;
  final String? backdropPath;
  final String? releaseDate;
  final List<String> genres;
  final String? fileHash;
  final String dateAdded;
  final String lastUpdated;
  final bool isFavorite;

  /// TMDB id parsed from [detailsJson], used to fetch episode-level metadata.
  /// Null when the item hasn't been enriched or predates id storage.
  Object? get tmdbId {
    final raw = detailsJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded['tmdbId'];
    } catch (_) {
      // Not metadata JSON.
    }
    return null;
  }

  Media copyWith({
    String? id,
    String? title,
    String? year,
    MediaType? type,
    String? path,
    String? fullPath,
    String? posterPath,
    String? rating,
    String? detailsJson,
    String? overview,
    String? backdropPath,
    String? releaseDate,
    List<String>? genres,
    String? fileHash,
    String? dateAdded,
    String? lastUpdated,
    bool? isFavorite,
  }) {
    return Media(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      type: type ?? this.type,
      path: path ?? this.path,
      fullPath: fullPath ?? this.fullPath,
      posterPath: posterPath ?? this.posterPath,
      rating: rating ?? this.rating,
      detailsJson: detailsJson ?? this.detailsJson,
      overview: overview ?? this.overview,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      genres: genres ?? this.genres,
      fileHash: fileHash ?? this.fileHash,
      dateAdded: dateAdded ?? this.dateAdded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Builds a [Media] from raw stored columns, parsing [details] JSON for the
  /// enhancement fields. Tolerates both camelCase and snake_case keys.
  factory Media.fromStored({
    required String id,
    required String title,
    required String year,
    required String type,
    required String path,
    String? fullPath,
    String? posterPath,
    String? rating,
    String? details,
    String? fileHash,
    required String dateAdded,
    required String lastUpdated,
    bool isFavorite = false,
  }) {
    String? overview;
    String? backdropPath;
    String? releaseDate;
    var genres = const <String>[];

    if (details != null && details.isNotEmpty) {
      try {
        final json = jsonDecode(details);
        if (json is Map<String, dynamic>) {
          overview = json['overview'] as String?;
          backdropPath =
              (json['backdropPath'] ?? json['backdrop_path']) as String?;
          releaseDate =
              (json['releaseDate'] ?? json['release_date']) as String?;
          final rawGenres = json['genres'];
          if (rawGenres is List) {
            genres = rawGenres
                .map((e) {
                  if (e is String) return e;
                  if (e is Map) return e['name']?.toString() ?? '';
                  return '';
                })
                .where((s) => s.isNotEmpty)
                .toList(growable: false);
          }
        }
      } catch (_) {
        // details is not metadata JSON; leave enhancement fields empty.
      }
    }

    return Media(
      id: id,
      title: title,
      year: year,
      type: MediaType.fromString(type),
      path: path,
      fullPath: fullPath,
      posterPath: posterPath,
      rating: rating,
      detailsJson: details,
      overview: overview,
      backdropPath: backdropPath,
      releaseDate: releaseDate,
      genres: genres,
      fileHash: fileHash,
      dateAdded: dateAdded,
      lastUpdated: lastUpdated,
      isFavorite: isFavorite,
    );
  }
}
