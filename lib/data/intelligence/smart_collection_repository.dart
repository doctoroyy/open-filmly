import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'agent_models.dart';
import 'intelligence_database.dart';

class SmartCollectionRepository {
  SmartCollectionRepository(this._database);

  final IntelligenceDatabase _database;

  Future<SmartCollection> upsert({
    required String name,
    required String query,
    required List<String> mediaIds,
  }) async {
    final id = sha256.convert(utf8.encode('$name|$query')).toString();
    final now = DateTime.now().toIso8601String();
    await _database
        .into(_database.smartCollections)
        .insertOnConflictUpdate(
          SmartCollectionsCompanion.insert(
            id: id,
            name: name,
            query: query,
            mediaIdsJson: jsonEncode(mediaIds),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getById(id))!;
  }

  Future<SmartCollection?> getById(String id) async {
    final row = await (_database.select(
      _database.smartCollections,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<SmartCollection>> list() async {
    final rows = await (_database.select(
      _database.smartCollections,
    )..orderBy([(item) => OrderingTerm.desc(item.updatedAt)])).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<void> deleteById(String id) => (_database.delete(
    _database.smartCollections,
  )..where((item) => item.id.equals(id))).go();

  SmartCollection _toDomain(SmartCollectionRow row) {
    final rawIds = jsonDecode(row.mediaIdsJson);
    return SmartCollection(
      id: row.id,
      name: row.name,
      query: row.query,
      mediaIds: rawIds is List
          ? rawIds.map((id) => id.toString()).toList(growable: false)
          : const [],
      createdAt:
          DateTime.tryParse(row.createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(row.updatedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
