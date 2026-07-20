import 'dart:typed_data';
import 'dart:math' as math;

import 'intelligence_database.dart';

class EmbeddingSearchHit {
  const EmbeddingSearchHit({
    required this.assetId,
    required this.segmentId,
    required this.score,
  });

  final String assetId;
  final String segmentId;
  final double score;
}

/// Stores model-specific vectors in the Intelligence database only.
class EmbeddingRepository {
  EmbeddingRepository(this._database);

  final IntelligenceDatabase _database;

  Future<void> upsert({
    required String id,
    required String assetId,
    required String segmentId,
    required String model,
    required List<double> vector,
    String modality = 'text',
  }) async {
    await _database
        .into(_database.embeddingItems)
        .insertOnConflictUpdate(
          EmbeddingItemsCompanion.insert(
            id: id,
            assetId: assetId,
            segmentId: segmentId,
            modality: modality,
            model: model,
            dimensions: vector.length,
            vector: _encode(vector),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
  }

  Future<List<EmbeddingSearchHit>> search({
    required String model,
    required List<double> vector,
    int limit = 24,
  }) async {
    if (vector.isEmpty) return const [];
    final rows = await (_database.select(
      _database.embeddingItems,
    )..where((row) => row.model.equals(model))).get();
    final hits = <EmbeddingSearchHit>[];
    for (final row in rows) {
      final candidate = _decode(row.vector, row.dimensions);
      final score = _cosine(vector, candidate);
      if (score.isFinite) {
        hits.add(
          EmbeddingSearchHit(
            assetId: row.assetId,
            segmentId: row.segmentId,
            score: score,
          ),
        );
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList(growable: false);
  }

  Future<void> deleteForAsset(String assetId) async {
    await (_database.delete(
      _database.embeddingItems,
    )..where((row) => row.assetId.equals(assetId))).go();
  }

  Uint8List _encode(List<double> values) {
    final bytes = ByteData(values.length * 8);
    for (var i = 0; i < values.length; i++) {
      bytes.setFloat64(i * 8, values[i], Endian.little);
    }
    return Uint8List.fromList(bytes.buffer.asUint8List());
  }

  List<double> _decode(Uint8List bytes, int dimensions) {
    if (bytes.length < dimensions * 8) return const [];
    final data = ByteData.sublistView(bytes);
    return List<double>.generate(
      dimensions,
      (index) => data.getFloat64(index * 8, Endian.little),
      growable: false,
    );
  }

  double _cosine(List<double> left, List<double> right) {
    if (left.length != right.length || left.isEmpty) return double.nan;
    var dot = 0.0;
    var leftNorm = 0.0;
    var rightNorm = 0.0;
    for (var i = 0; i < left.length; i++) {
      dot += left[i] * right[i];
      leftNorm += left[i] * left[i];
      rightNorm += right[i] * right[i];
    }
    if (leftNorm == 0 || rightNorm == 0) return double.nan;
    return dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
  }
}
