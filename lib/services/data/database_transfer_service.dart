import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../data/database/database.dart';

/// Counts rows copied by a database import/export operation.
class DatabaseTransferResult {
  const DatabaseTransferResult({
    required this.mediaRows,
    required this.episodeRows,
    required this.configRows,
  });

  final int mediaRows;
  final int episodeRows;
  final int configRows;
}

/// Copies the portable SQLite database used by Open Filmly between devices.
///
/// The app database is platform-local, so installing a new binary cannot move
/// it from macOS to iOS. This service deliberately merges rows into the
/// current database instead of replacing it, preserving local iOS media and
/// the newer playback position when both devices have the same item.
class DatabaseTransferService {
  DatabaseTransferService(this._target);

  static const _playbackPrefix = 'playback_progress:';

  final AppDatabase _target;

  /// Imports a database opened by the caller. Kept public for tests and for
  /// future platform-specific transfer channels.
  Future<DatabaseTransferResult> mergeFrom(AppDatabase source) async {
    final mediaRows = await source.select(source.mediaItems).get();
    final episodeRows = await source.select(source.episodes).get();
    final configRows = await source.select(source.configEntries).get();

    await _target.transaction(() async {
      for (final row in mediaRows) {
        final current = await (_target.select(
          _target.mediaItems,
        )..where((item) => item.id.equals(row.id))).getSingleOrNull();
        final favorite = row.isFavorite || (current?.isFavorite ?? false);
        await _target
            .into(_target.mediaItems)
            .insertOnConflictUpdate(
              row.toCompanion(false).copyWith(isFavorite: Value(favorite)),
            );
      }

      for (final row in episodeRows) {
        await _target
            .into(_target.episodes)
            .insertOnConflictUpdate(row.toCompanion(false));
      }

      for (final row in configRows) {
        final current = await (_target.select(
          _target.configEntries,
        )..where((entry) => entry.key.equals(row.key))).getSingleOrNull();
        final value = _mergeConfigValue(row.key, row.value, current?.value);
        await _target
            .into(_target.configEntries)
            .insertOnConflictUpdate(
              ConfigEntriesCompanion.insert(key: row.key, value: value),
            );
      }
    });

    return DatabaseTransferResult(
      mediaRows: mediaRows.length,
      episodeRows: episodeRows.length,
      configRows: configRows.length,
    );
  }

  /// Imports a SQLite snapshot selected from Files, AirDrop, or a desktop
  /// file picker. The source remains untouched and is closed after reading.
  Future<DatabaseTransferResult> importFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('迁移文件不存在：$path');
    }
    final source = AppDatabase(NativeDatabase(file, enableMigrations: false));
    try {
      return await mergeFrom(source);
    } finally {
      await source.close();
    }
  }

  /// Writes a complete SQLite snapshot. A temporary sibling file prevents a
  /// partially-written backup if the app is interrupted during export.
  Future<File> exportToPath(String path) async {
    final output = File(path);
    final temporary = File('$path.tmp');
    if (await temporary.exists()) await temporary.delete();

    final snapshot = AppDatabase(NativeDatabase(temporary));
    try {
      final mediaRows = await _target.select(_target.mediaItems).get();
      final episodeRows = await _target.select(_target.episodes).get();
      final configRows = await _target.select(_target.configEntries).get();

      await snapshot.transaction(() async {
        await snapshot.delete(snapshot.episodes).go();
        await snapshot.delete(snapshot.mediaItems).go();
        await snapshot.delete(snapshot.configEntries).go();
        for (final row in mediaRows) {
          await snapshot
              .into(snapshot.mediaItems)
              .insert(row.toCompanion(false));
        }
        for (final row in episodeRows) {
          await snapshot.into(snapshot.episodes).insert(row.toCompanion(false));
        }
        for (final row in configRows) {
          await snapshot
              .into(snapshot.configEntries)
              .insert(row.toCompanion(false));
        }
      });
    } finally {
      await snapshot.close();
    }

    if (await output.exists()) await output.delete();
    return temporary.rename(path);
  }

  String _mergeConfigValue(String key, String incoming, String? current) {
    if (current == null || !key.startsWith(_playbackPrefix)) {
      return incoming;
    }

    final incomingAt = _updatedAt(incoming);
    final currentAt = _updatedAt(current);
    if (incomingAt == null || currentAt == null) return incoming;
    return currentAt.isAfter(incomingAt) ? current : incoming;
  }

  DateTime? _updatedAt(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }
}
