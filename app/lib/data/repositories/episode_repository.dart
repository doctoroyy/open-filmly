import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/episode.dart';

/// Data access for episodes associated with TV shows.
class EpisodeRepository {
  EpisodeRepository(this._db);

  final AppDatabase _db;

  Future<List<Episode>> getByShow(String showId) async {
    final rows =
        await (_db.select(_db.episodes)
              ..where((t) => t.showId.equals(showId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.seasonNumber),
                (t) => OrderingTerm.asc(t.episodeNumber),
              ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
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
    final countExp = _db.episodes.id.count();
    final result =
        await (_db.selectOnly(_db.episodes)
              ..addColumns([countExp])
              ..where(_db.episodes.showId.equals(showId)))
            .map((row) => row.read(countExp) ?? 0)
            .getSingle();
    return result;
  }

  /// 删除指定电视剧的所有剧集
  Future<void> deleteByShow(String showId) async {
    await (_db.delete(_db.episodes)..where((t) => t.showId.equals(showId))).go();
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
}
