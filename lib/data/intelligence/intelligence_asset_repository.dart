import 'package:drift/drift.dart';

import 'intelligence_database.dart';
import '../../services/intelligence/media_identity_service.dart';

class IntelligenceAssetRepository {
  IntelligenceAssetRepository(this._database);

  final IntelligenceDatabase _database;

  Future<void> upsert({
    required MediaIdentity identity,
    String? mediaId,
    String? episodeId,
    String status = 'pending',
    int? durationMs,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database
        .into(_database.intelligenceAssets)
        .insertOnConflictUpdate(
          IntelligenceAssetsCompanion.insert(
            id: identity.identityKey,
            mediaId: Value(mediaId),
            episodeId: Value(episodeId),
            sourceScope: identity.sourceScope,
            canonicalUri: identity.canonicalUri,
            identityKey: identity.identityKey,
            fileHash: Value(identity.fileHash),
            fileSize: Value(identity.fileSize),
            modifiedAt: Value(identity.modifiedAt?.millisecondsSinceEpoch),
            durationMs: Value(durationMs),
            status: Value(status),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<IntelligenceAssetRow?> getById(String id) {
    return (_database.select(
      _database.intelligenceAssets,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<List<IntelligenceAssetRow>> list({int limit = 1000}) {
    return (_database.select(_database.intelligenceAssets)
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
          ..limit(limit))
        .get();
  }

  Future<IntelligenceAssetRow?> getByMediaId(String mediaId) {
    return (_database.select(_database.intelligenceAssets)
          ..where((row) => row.mediaId.equals(mediaId))
          ..limit(1))
        .getSingleOrNull();
  }
}
