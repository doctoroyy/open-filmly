import 'package:drift/drift.dart';

/// Mirrors the Electron `media` table so an existing media.db can be opened
/// later without migration. All columns are TEXT, matching the original schema.
@DataClassName('MediaRow')
class MediaItems extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get year => text().withDefault(const Constant(''))();
  TextColumn get type => text()(); // movie | tv | unknown
  TextColumn get path => text()();
  TextColumn get fullPath => text().nullable()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get rating => text().nullable()();
  TextColumn get details => text().nullable()(); // TMDB metadata JSON blob
  TextColumn get fileHash => text().nullable()();
  TextColumn get dateAdded => text()();
  TextColumn get lastUpdated => text()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'media';
}

/// Episodes belonging to a TV show. Each row links back to a parent media item
/// (type=tv) and carries season/episode numbering plus a file path.
@DataClassName('EpisodeRow')
class Episodes extends Table {
  TextColumn get id => text()();
  TextColumn get showId => text().references(MediaItems, #id)();
  IntColumn get seasonNumber => integer()();
  IntColumn get episodeNumber => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get path => text()();
  TextColumn get fullPath => text().nullable()();
  TextColumn get dateAdded => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'episodes';
}

/// Key-value config table. The app stores its whole config object as JSON under
/// the single key `app_config`, matching the Electron implementation.
@DataClassName('ConfigRow')
class ConfigEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  @override
  String get tableName => 'config';
}
