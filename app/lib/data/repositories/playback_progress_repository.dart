import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/playback_progress.dart';

/// Persists playback resume points in the shared config key-value store.
class PlaybackProgressRepository {
  PlaybackProgressRepository(this._db);

  static const _keyPrefix = 'playback_progress:';

  final AppDatabase _db;

  Future<PlaybackProgress?> getByMediaId(String mediaId) async {
    final row = await (_db.select(
      _db.configEntries,
    )..where((t) => t.key.equals(_keyFor(mediaId)))).getSingleOrNull();
    if (row == null) return null;
    return _decode(mediaId, row.value);
  }

  Future<List<PlaybackProgress>> getContinueWatching({int limit = 12}) async {
    final rows = await (_db.select(
      _db.configEntries,
    )..where((t) => t.key.like('$_keyPrefix%'))).get();

    final items =
        rows
            .map((row) {
              final mediaId = row.key.substring(_keyPrefix.length);
              return _decode(mediaId, row.value);
            })
            .whereType<PlaybackProgress>()
            .where((progress) => progress.shouldSurface)
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return items.take(limit).toList(growable: false);
  }

  Future<void> save(PlaybackProgress progress) async {
    await _db
        .into(_db.configEntries)
        .insertOnConflictUpdate(
          ConfigEntriesCompanion.insert(
            key: _keyFor(progress.mediaId),
            value: jsonEncode(progress.toJson()),
          ),
        );
  }

  Future<void> clear(String mediaId) async {
    await (_db.delete(
      _db.configEntries,
    )..where((t) => t.key.equals(_keyFor(mediaId)))).go();
  }

  PlaybackProgress? _decode(String mediaId, String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return PlaybackProgress.fromJson(mediaId, json);
    } catch (_) {
      return null;
    }
  }

  String _keyFor(String mediaId) => '$_keyPrefix$mediaId';
}
