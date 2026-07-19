import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/database.dart';
import '../models/episode.dart';

/// Data access for episodes associated with TV shows.
class EpisodeRepository {
  EpisodeRepository(this._db);

  final AppDatabase _db;

  Future<List<Episode>> getByShow(String showId) async {
    final rows = await _rawRowsByShow(showId);
    final unique = <(int, int), Episode>{};
    for (final row in rows) {
      final episode = _toDomain(row);
      final key = (episode.seasonNumber, episode.episodeNumber);
      final current = unique[key];
      if (current == null || _quality(episode) > _quality(current)) {
        unique[key] = episode;
      }
    }

    final episodes = unique.values.toList(growable: false);
    episodes.sort((a, b) {
      final season = a.seasonNumber.compareTo(b.seasonNumber);
      return season != 0 ? season : a.episodeNumber.compareTo(b.episodeNumber);
    });
    return episodes;
  }

  /// Returns every stored row without collapsing duplicate season/episode
  /// numbers. Startup repair uses this to recover older rows that were all
  /// written as S01E01, and to remove AppleDouble sidecars individually.
  Future<List<Episode>> getRawByShow(String showId) async {
    final rows = await _rawRowsByShow(showId);
    return rows.map(_toDomain).toList(growable: false);
  }

  /// Removes rows that point at the exact same physical episode file. A show
  /// may still legitimately have two different files for one episode (for
  /// example local and SMB alternatives), so the path is part of the key.
  Future<int> removeExactDuplicates() async {
    final rows = await (_db.select(
      _db.episodes,
    )..orderBy([(t) => OrderingTerm.asc(t.dateAdded)])).get();
    final kept = <String, Episode>{};
    var removed = 0;
    for (final row in rows) {
      final episode = _toDomain(row);
      final key = [
        episode.showId,
        episode.seasonNumber,
        episode.episodeNumber,
        episode.path,
        episode.fullPath ?? '',
      ].join('\u0000');
      final previous = kept[key];
      if (previous == null) {
        kept[key] = episode;
        continue;
      }

      final preferred = _quality(episode) > _quality(previous)
          ? episode
          : previous;
      final duplicate = preferred.id == episode.id ? previous : episode;
      await deleteById(duplicate.id);
      kept[key] = preferred;
      removed++;
    }
    return removed;
  }

  /// Returns episodes grouped into [Season] objects, sorted ascending.
  Future<List<Season>> getByShowGrouped(String showId) async {
    final episodes = await getByShow(showId);
    final map = <int, List<Episode>>{};
    for (final ep in episodes) {
      map.putIfAbsent(ep.seasonNumber, () => []).add(ep);
    }
    final seasons =
        map.entries
            .map((e) => Season(number: e.key, episodes: e.value))
            .toList(growable: false)
          ..sort((a, b) => a.number.compareTo(b.number));
    return seasons;
  }

  Future<void> upsert(Episode episode) async {
    final now = DateTime.now().toIso8601String();
    await _db
        .into(_db.episodes)
        .insertOnConflictUpdate(
          EpisodesCompanion.insert(
            id: episode.id,
            showId: episode.showId,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            title: Value(episode.title),
            path: episode.path,
            fullPath: Value(episode.fullPath),
            dateAdded: episode.dateAdded.isEmpty ? now : episode.dateAdded,
          ),
        );
  }

  Future<void> upsertAll(List<Episode> episodes) async {
    await _db.batch((batch) {
      final now = DateTime.now().toIso8601String();
      for (final episode in episodes) {
        batch.insert(
          _db.episodes,
          EpisodesCompanion.insert(
            id: episode.id,
            showId: episode.showId,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            title: Value(episode.title),
            path: episode.path,
            fullPath: Value(episode.fullPath),
            dateAdded: episode.dateAdded.isEmpty ? now : episode.dateAdded,
          ),
          onConflict: DoUpdate(
            (old) => EpisodesCompanion(
              showId: Value(episode.showId),
              seasonNumber: Value(episode.seasonNumber),
              episodeNumber: Value(episode.episodeNumber),
              title: Value(episode.title),
              path: Value(episode.path),
              fullPath: Value(episode.fullPath),
            ),
          ),
        );
      }
    });
  }

  Future<int> countByShow(String showId) async {
    return (await getByShow(showId)).length;
  }

  /// 删除指定电视剧的所有剧集
  Future<void> deleteByShow(String showId) async {
    await (_db.delete(
      _db.episodes,
    )..where((t) => t.showId.equals(showId))).go();
  }

  /// Deletes a single episode row by id.
  Future<void> deleteById(String id) async {
    await (_db.delete(_db.episodes)..where((t) => t.id.equals(id))).go();
  }

  Episode _toDomain(EpisodeRow row) => Episode(
    id: row.id,
    showId: row.showId,
    seasonNumber: row.seasonNumber,
    episodeNumber: row.episodeNumber,
    title: row.title,
    path: row.path,
    fullPath: row.fullPath,
    dateAdded: row.dateAdded,
  );

  Future<List<EpisodeRow>> _rawRowsByShow(String showId) {
    return (_db.select(_db.episodes)
          ..where((t) => t.showId.equals(showId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.seasonNumber),
            (t) => OrderingTerm.asc(t.episodeNumber),
          ]))
        .get();
  }

  static const _videoExtensions = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.m4v',
    '.wmv',
    '.flv',
    '.webm',
    '.ts',
    '.m2ts',
  };

  /// Prefer a real playable file over stale generated rows and macOS
  /// AppleDouble sidecars when older library versions produced duplicates.
  static int _quality(Episode episode) {
    final path = episode.path;
    final full = episode.fullPath ?? '';
    final source = full.isNotEmpty ? full : path;
    final name = p.basename(source);
    if (name.startsWith('._') || name.startsWith('.')) return -100;
    // Synthetic ids left by older default-episode injection.
    if (path.startsWith('tv:') || full.startsWith('tv:')) return -50;

    var score = 0;
    if (_videoExtensions.contains(p.extension(source).toLowerCase())) {
      score += 20;
    }
    if (path.startsWith('smb://') || path.startsWith('/')) score += 5;
    if (full.isNotEmpty) score += 2;
    return score;
  }
}
