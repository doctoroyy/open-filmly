import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/library_shelf.dart';
import '../models/media.dart';
import '../models/media_library_query.dart';

/// Data access for the media library. Mirrors the query surface of the Electron
/// MediaDatabase (getByType / getById / upsert / updatePoster / counts).
class MediaRepository {
  MediaRepository(this._db);

  final AppDatabase _db;

  Future<List<Media>> getByType(MediaType type) async {
    return browse(type: type);
  }

  Future<Media?> getById(String id) async {
    final row = await (_db.select(
      _db.mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<Media>> getRecentlyAdded({int limit = 12}) async {
    return browse(sort: MediaSort.recentlyAdded, limit: limit);
  }

  Future<List<Media>> browse({
    MediaType? type,
    LibraryShelf? shelf,
    String searchTerm = '',
    MediaSort sort = MediaSort.title,
    int? limit,
    List<String> genreTerms = const [],
  }) async {
    final query = _db.select(_db.mediaItems);
    // When filtering by exclusive shelf, load all rows then classify in memory
    // (genres live in details JSON). Type-only queries can still push SQL.
    if (shelf == null && type != null) {
      query.where((t) => t.type.equals(type.value));
    }

    var items = (await query.get()).map(_toDomain).toList();

    if (shelf != null) {
      items = items
          .where((media) => LibraryShelfClassifier.matches(media, shelf))
          .toList();
    } else if (type != null) {
      // already filtered in SQL; keep for clarity if both null paths change
    }

    final normalized = searchTerm.trim().toLowerCase();
    final searchFiltered = normalized.isEmpty
        ? items
        : items.where((media) => _matchesSearch(media, normalized)).toList();

    final normalizedGenreTerms = genreTerms
        .map((term) => term.trim().toLowerCase())
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    final filtered = normalizedGenreTerms.isEmpty
        ? searchFiltered
        : searchFiltered
              .where((media) => _matchesGenreTerms(media, normalizedGenreTerms))
              .toList();

    filtered.sort((a, b) => _compareMedia(a, b, sort));

    if (limit != null && filtered.length > limit) {
      return filtered.take(limit).toList(growable: false);
    }
    return filtered;
  }

  Future<List<Media>> search(
    String query, {
    MediaSort sort = MediaSort.recentlyAdded,
    int limit = 24,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    return browse(searchTerm: normalized, sort: sort, limit: limit);
  }

  Future<void> upsert(Media media) async {
    final now = DateTime.now().toIso8601String();
    await _db
        .into(_db.mediaItems)
        .insertOnConflictUpdate(
          MediaItemsCompanion.insert(
            id: media.id,
            title: media.title,
            year: Value(media.year),
            type: media.type.value,
            path: media.path,
            fullPath: Value(media.fullPath),
            posterPath: Value(media.posterPath),
            rating: Value(media.rating),
            details: Value(media.detailsJson),
            fileHash: Value(media.fileHash),
            dateAdded: media.dateAdded.isEmpty ? now : media.dateAdded,
            lastUpdated: now,
          ),
        );
  }

  /// Upserts a filesystem/network scan result without erasing metadata that a
  /// previous TMDB match already attached to the same logical item.
  Future<void> upsertScanned(Media media) async {
    final existing = await getById(media.id);
    if (existing == null) {
      await upsert(media);
      return;
    }
    final hasCuratedMetadata = existing.tmdbId != null;
    await upsert(
      media.copyWith(
        title: hasCuratedMetadata ? existing.title : media.title,
        year: hasCuratedMetadata && existing.year.isNotEmpty
            ? existing.year
            : media.year,
        posterPath: existing.posterPath,
        rating: existing.rating,
        detailsJson: existing.detailsJson ?? media.detailsJson,
        fileHash: existing.fileHash,
        dateAdded: existing.dateAdded,
        isFavorite: existing.isFavorite,
      ),
    );
  }

  /// Merges legacy path-based TV rows into [canonical]. Episodes retain their
  /// physical file paths but now point to one logical show across season
  /// folders. Returns the number of obsolete show rows removed.
  Future<int> consolidateTvShow(Media canonical) async {
    if (canonical.type != MediaType.tv) return 0;
    final allShows = await browse(type: MediaType.tv);
    final canonicalScope = _sourceScope(canonical);
    final canonicalTitle = _normalizedShowTitle(canonical.title);
    final duplicates = allShows
        .where(
          (item) =>
              item.id != canonical.id &&
              _sourceScope(item) == canonicalScope &&
              _normalizedShowTitle(item.title) == canonicalTitle,
        )
        .toList(growable: false);
    if (duplicates.isEmpty) return 0;

    final candidates = [canonical, ...duplicates]
      ..sort((a, b) => _metadataQuality(b).compareTo(_metadataQuality(a)));
    final donor = candidates.first;
    final canonicalSourceDetails = canonical.detailsJson;
    await upsert(
      canonical.copyWith(
        title: donor.title,
        year: donor.year.isNotEmpty ? donor.year : canonical.year,
        posterPath: donor.posterPath ?? canonical.posterPath,
        rating: donor.rating ?? canonical.rating,
        detailsJson: _mergeDetails(donor.detailsJson, canonicalSourceDetails),
        fileHash: donor.fileHash ?? canonical.fileHash,
        dateAdded: donor.dateAdded.isNotEmpty
            ? donor.dateAdded
            : canonical.dateAdded,
        isFavorite:
            canonical.isFavorite || duplicates.any((item) => item.isFavorite),
      ),
    );

    for (final duplicate in duplicates) {
      await (_db.update(_db.episodes)
            ..where((row) => row.showId.equals(duplicate.id)))
          .write(EpisodesCompanion(showId: Value(canonical.id)));
      await (_db.delete(
        _db.mediaItems,
      )..where((row) => row.id.equals(duplicate.id))).go();
    }
    return duplicates.length;
  }

  Future<void> updatePoster(String id, String posterPath) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        posterPath: Value(posterPath),
        lastUpdated: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Count of items per [MediaType], for the home dashboard.
  Future<Map<MediaType, int>> countByType() async {
    final counts = <MediaType, int>{};
    for (final type in MediaType.values) {
      final countExp = _db.mediaItems.id.count();
      final value =
          await (_db.selectOnly(_db.mediaItems)
                ..addColumns([countExp])
                ..where(_db.mediaItems.type.equals(type.value)))
              .map((row) => row.read(countExp) ?? 0)
              .getSingle();
      counts[type] = value;
    }
    return counts;
  }

  /// Returns IDs of items that have no poster (i.e. need metadata enrichment).
  Future<List<String>> getIdsWithoutPoster() async {
    final rows = await (_db.select(
      _db.mediaItems,
    )..where((t) => t.posterPath.isNull() | t.posterPath.equals(''))).get();
    return rows.map((r) => r.id).toList(growable: false);
  }

  /// Returns all media IDs in the library.
  Future<List<String>> getAllIds() async {
    final rows =
        await (_db.selectOnly(_db.mediaItems)..addColumns([_db.mediaItems.id]))
            .map((row) => row.read(_db.mediaItems.id)!)
            .get();
    return rows;
  }

  /// Deletes all media entries and their episodes.
  /// Used before a full rescan to clear stale data.
  ///
  /// Deletes episodes first to satisfy the foreign key constraint, then media.
  Future<void> deleteAll() async {
    // Delete episodes first (foreign key references mediaItems.id)
    await _db.delete(_db.episodes).go();
    await _db.delete(_db.mediaItems).go();
  }

  /// Removes a single media item (and its episodes) by id. Used to purge junk
  /// rows (e.g. macOS `._` sidecars) discovered after the fact.
  Future<void> deleteById(String id) async {
    await (_db.delete(_db.episodes)..where((t) => t.showId.equals(id))).go();
    await (_db.delete(_db.mediaItems)..where((t) => t.id.equals(id))).go();
  }

  /// Marks (or unmarks) a media item as a favorite.
  Future<void> setFavorite(String id, bool value) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(isFavorite: Value(value)),
    );
  }

  /// All favorited items, most recently added first.
  Future<List<Media>> getFavorites() async {
    final rows = await (_db.select(
      _db.mediaItems,
    )..where((t) => t.isFavorite.equals(true))).get();
    final items = rows.map(_toDomain).toList();
    items.sort((a, b) => _compareDateStrings(b.dateAdded, a.dateAdded));
    return items;
  }

  Media _toDomain(MediaRow row) => Media.fromStored(
    id: row.id,
    title: row.title,
    year: row.year,
    type: row.type,
    path: row.path,
    fullPath: row.fullPath,
    posterPath: row.posterPath,
    rating: row.rating,
    details: row.details,
    fileHash: row.fileHash,
    dateAdded: row.dateAdded,
    lastUpdated: row.lastUpdated,
    isFavorite: row.isFavorite,
  );

  bool _matchesSearch(Media media, String normalizedQuery) {
    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    final haystack = [
      media.title,
      media.year,
      media.overview ?? '',
      media.releaseDate ?? '',
      media.genres.join(' '),
      media.path,
      media.fullPath ?? '',
    ].join(' ').toLowerCase();

    return tokens.every(haystack.contains);
  }

  bool _matchesGenreTerms(Media media, List<String> normalizedTerms) {
    final haystack = [
      media.title,
      media.overview ?? '',
      media.genres.join(' '),
      media.path,
      media.fullPath ?? '',
    ].join(' ').toLowerCase();

    return normalizedTerms.any(haystack.contains);
  }

  int _compareMedia(Media a, Media b, MediaSort sort) {
    final primary = switch (sort) {
      MediaSort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      MediaSort.recentlyAdded => _compareDateStrings(b.dateAdded, a.dateAdded),
      MediaSort.year => _compareYearsDescending(a.year, b.year),
      MediaSort.rating => _compareRatingsDescending(a.rating, b.rating),
    };

    if (primary != 0) return primary;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  int _compareDateStrings(String left, String right) {
    final leftDate = DateTime.tryParse(left);
    final rightDate = DateTime.tryParse(right);
    final leftMillis = leftDate?.millisecondsSinceEpoch ?? 0;
    final rightMillis = rightDate?.millisecondsSinceEpoch ?? 0;
    return leftMillis.compareTo(rightMillis);
  }

  int _compareYearsDescending(String left, String right) {
    final leftYear = int.tryParse(left) ?? 0;
    final rightYear = int.tryParse(right) ?? 0;
    return rightYear.compareTo(leftYear);
  }

  int _compareRatingsDescending(String? left, String? right) {
    final leftRating = double.tryParse(left ?? '') ?? -1;
    final rightRating = double.tryParse(right ?? '') ?? -1;
    return rightRating.compareTo(leftRating);
  }

  String _normalizedShowTitle(String title) => title.toLowerCase().replaceAll(
    RegExp(r'[^\u4e00-\u9fff\u3400-\u4dbfa-z0-9]+'),
    '',
  );

  String _sourceScope(Media media) {
    final raw = media.detailsJson;
    if (raw == null || raw.isEmpty) return 'local';
    try {
      final decoded = jsonDecode(raw);
      final source = decoded is Map<String, dynamic> ? decoded['source'] : null;
      if (source is! Map) return 'local';
      final kind = source['kind']?.toString() ?? 'local';
      return switch (kind) {
        'smb' =>
          'smb|${source['host']?.toString().toLowerCase() ?? ''}|'
              '${source['share']?.toString().toLowerCase() ?? ''}',
        'webdav' =>
          'webdav|${source['base']?.toString().trim().toLowerCase() ?? ''}',
        'emby' =>
          'emby|${source['base']?.toString().trim().toLowerCase() ?? ''}',
        _ => kind,
      };
    } catch (_) {
      return 'local';
    }
  }

  int _metadataQuality(Media media) {
    var score = 0;
    if (media.tmdbId != null) score += 100;
    if (media.posterPath?.isNotEmpty == true) score += 30;
    if (media.rating?.isNotEmpty == true) score += 10;
    if (media.detailsJson?.isNotEmpty == true) score += 5;
    if (media.isFavorite) score += 2;
    return score;
  }

  String? _mergeDetails(String? donor, String? canonicalSource) {
    Map<String, dynamic>? donorMap;
    Map<String, dynamic>? sourceMap;
    try {
      final decoded = donor == null ? null : jsonDecode(donor);
      if (decoded is Map<String, dynamic>) donorMap = decoded;
    } catch (_) {}
    try {
      final decoded = canonicalSource == null
          ? null
          : jsonDecode(canonicalSource);
      if (decoded is Map<String, dynamic>) sourceMap = decoded;
    } catch (_) {}
    if (donorMap == null && sourceMap == null) return donor ?? canonicalSource;
    return jsonEncode({
      ...?donorMap,
      if (sourceMap?['source'] != null) 'source': sourceMap!['source'],
    });
  }
}
