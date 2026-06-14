import 'dart:convert';

import '../database/database.dart';
import '../models/app_config.dart';

/// Reads and writes the singleton [AppConfig] stored under the `app_config`
/// config key, matching the Electron config persistence scheme.
class ConfigRepository {
  ConfigRepository(this._db);

  final AppDatabase _db;

  static const _appConfigKey = 'app_config';

  Future<AppConfig> load() async {
    final row = await (_db.select(
      _db.configEntries,
    )..where((t) => t.key.equals(_appConfigKey))).getSingleOrNull();
    if (row == null) return const AppConfig();
    try {
      final json = jsonDecode(row.value) as Map<String, dynamic>;
      return AppConfig.fromJson(json);
    } catch (_) {
      return const AppConfig();
    }
  }

  Future<void> save(AppConfig config) async {
    await _db
        .into(_db.configEntries)
        .insertOnConflictUpdate(
          ConfigEntriesCompanion.insert(
            key: _appConfigKey,
            value: jsonEncode(config.toJson()),
          ),
        );
  }
}
