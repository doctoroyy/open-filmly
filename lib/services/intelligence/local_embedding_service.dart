import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../data/intelligence/intelligence_database.dart';
import 'transcript_service.dart';

/// Offline lexical embeddings for private media libraries.
///
/// This is deliberately dependency-free: when a local AI worker is unavailable,
/// Filmly can still rank scene-like results with a stable hashed bag-of-tokens
/// vector. When a real embedding model is later configured, the same table can
/// store provider vectors under a different [model] name.
class LocalEmbeddingService {
  LocalEmbeddingService(this._database, this._transcripts);

  static const modelName = 'filmly-local-hash-v1';
  static const dimensions = 256;

  final IntelligenceDatabase _database;
  final TranscriptService _transcripts;

  Future<int> rebuildFromTranscripts(String assetId) async {
    final segments = await _transcripts.getByAsset(assetId);
    await (_database.delete(
      _database.embeddingItems,
    )..where((row) => row.assetId.equals(assetId) & row.model.equals(modelName)))
        .go();
    if (segments.isEmpty) return 0;

    final now = DateTime.now().toIso8601String();
    var written = 0;
    await _database.batch((batch) {
      for (final segment in segments) {
        final text = [
          segment.text,
          if (segment.translatedText?.trim().isNotEmpty == true)
            segment.translatedText!,
        ].join(' ');
        final vector = embedText(text);
        batch.insert(
          _database.embeddingItems,
          EmbeddingItemsCompanion.insert(
            id: '${segment.id}:$modelName',
            assetId: assetId,
            segmentId: segment.id,
            modality: 'transcript',
            model: modelName,
            dimensions: dimensions,
            vector: _encode(vector),
            createdAt: now,
          ),
          onConflict: DoUpdate(
            (_) => EmbeddingItemsCompanion(
              vector: Value(_encode(vector)),
              dimensions: const Value(dimensions),
              createdAt: Value(now),
            ),
          ),
        );
        written += 1;
      }
    });
    return written;
  }

  Future<List<LocalEmbeddingHit>> search(
    String query, {
    int limit = 24,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final queryVector = embedText(normalized);
    final rows =
        await (_database.select(_database.embeddingItems)
              ..where((row) => row.model.equals(modelName)))
            .get();
    if (rows.isEmpty) return const [];

    final hits = <LocalEmbeddingHit>[];
    for (final row in rows) {
      final vector = _decode(row.vector, row.dimensions);
      if (vector.isEmpty) continue;
      final score = _cosine(queryVector, vector);
      if (score <= 0.05) continue;
      hits.add(
        LocalEmbeddingHit(
          segmentId: row.segmentId,
          assetId: row.assetId,
          score: score,
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList(growable: false);
  }

  List<double> embedText(String text) {
    final vector = List<double>.filled(dimensions, 0);
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return vector;
    for (final token in tokens) {
      final hash = _stableHash(token);
      final index = hash % dimensions;
      final sign = (hash & 1) == 0 ? 1.0 : -1.0;
      vector[index] += sign;
    }
    return _l2Normalize(vector);
  }

  List<String> _tokenize(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return const [];
    final tokens = <String>[];
    for (final part in lower.split(RegExp(r'[^a-z0-9\u3400-\u9fff]+'))) {
      if (part.isEmpty) continue;
      if (RegExp(r'[\u3400-\u9fff]').hasMatch(part)) {
        // Character and bigram tokens keep short Chinese scene queries useful.
        final runes = part.runes.toList(growable: false);
        for (final rune in runes) {
          tokens.add(String.fromCharCode(rune));
        }
        for (var i = 0; i < runes.length - 1; i++) {
          tokens.add(
            String.fromCharCodes([runes[i], runes[i + 1]]),
          );
        }
      } else if (part.length > 1) {
        tokens.add(part);
      }
    }
    return tokens;
  }

  int _stableHash(String value) {
    final digest = utf8.encode(value);
    // FNV-1a 32-bit
    var hash = 0x811c9dc5;
    for (final byte in digest) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  Uint8List _encode(List<double> vector) {
    final data = ByteData(vector.length * 4);
    for (var i = 0; i < vector.length; i++) {
      data.setFloat32(i * 4, vector[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }

  List<double> _decode(Uint8List bytes, int dims) {
    if (bytes.length < dims * 4) return const [];
    final data = ByteData.sublistView(bytes);
    return List<double>.generate(
      dims,
      (index) => data.getFloat32(index * 4, Endian.little),
      growable: false,
    );
  }

  List<double> _l2Normalize(List<double> vector) {
    var sumSquares = 0.0;
    for (final value in vector) {
      sumSquares += value * value;
    }
    if (sumSquares <= 0) return vector;
    final norm = math.sqrt(sumSquares);
    return [for (final value in vector) value / norm];
  }

  double _cosine(List<double> left, List<double> right) {
    final length = math.min(left.length, right.length);
    var dot = 0.0;
    for (var i = 0; i < length; i++) {
      dot += left[i] * right[i];
    }
    return dot;
  }
}

class LocalEmbeddingHit {
  const LocalEmbeddingHit({
    required this.segmentId,
    required this.assetId,
    required this.score,
  });

  final String segmentId;
  final String assetId;
  final double score;
}
