import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// drift database for the media library and config. [executor] is injectable so
/// tests can pass an in-memory database; production uses drift_flutter's
/// platform-aware file located via path_provider.
@DriftDatabase(tables: [MediaItems, Episodes, ConfigEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'open_filmly'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(episodes);
      }
      if (from < 3) {
        await m.addColumn(mediaItems, mediaItems.isFavorite);
      }
    },
  );
}
