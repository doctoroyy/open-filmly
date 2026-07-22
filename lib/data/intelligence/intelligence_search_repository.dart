import 'package:drift/drift.dart';

import 'intelligence_database.dart';

class IntelligenceSearchHit {
  const IntelligenceSearchHit({
    required this.segmentId,
    required this.assetId,
    required this.startMs,
    required this.endMs,
    required this.content,
    required this.score,
  });

  final String segmentId;
  final String assetId;
  final int startMs;
  final int endMs;
  final String content;
  final double score;
}

class IntelligenceSearchRepository {
  IntelligenceSearchRepository(this._database);

  final IntelligenceDatabase _database;

  Future<List<IntelligenceSearchHit>> search(
    String query, {
    int limit = 24,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    try {
      final rows = await _database
          .customSelect(
            'SELECT segment_id, asset_id, start_ms, end_ms, content, bm25(intelligence_fts) AS score '
            'FROM intelligence_fts WHERE intelligence_fts MATCH ? '
            'ORDER BY score LIMIT ?',
            variables: [
              Variable.withString(normalized),
              Variable.withInt(limit),
            ],
          )
          .get();
      final hits = rows
          .map(
            (row) => IntelligenceSearchHit(
              segmentId: row.read<String>('segment_id'),
              assetId: row.read<String>('asset_id'),
              startMs: row.read<int>('start_ms'),
              endMs: row.read<int>('end_ms'),
              content: row.read<String>('content'),
              score: row.read<double>('score'),
            ),
          )
          .toList(growable: false);
      // FTS5's default tokenizer treats an uninterrupted Chinese phrase as a
      // single token. A query such as “雨夜长安” therefore returns no FTS hit
      // for “他在雨夜的长安城门…”, even though it is a useful scene match.
      // Fall back to the CJK-aware scan when FTS has no candidates.
      return hits.isEmpty ? _fallbackSearch(normalized, limit: limit) : hits;
    } catch (_) {
      return _fallbackSearch(normalized, limit: limit);
    }
  }

  Future<List<IntelligenceSearchHit>> _fallbackSearch(
    String query, {
    required int limit,
  }) async {
    final normalized = query.toLowerCase();
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final rows = await _database.select(_database.transcriptSegments).get();
    final hits = <IntelligenceSearchHit>[];
    for (final row in rows) {
      final content = row.content;
      final lower = content.toLowerCase();
      final exact = lower.contains(normalized);
      final cjkPhrase = _isCjkPhrase(normalized) &&
          _containsCharactersInOrder(lower, normalized);
      if (!exact && !cjkPhrase && !tokens.every(lower.contains)) continue;
      hits.add(
        IntelligenceSearchHit(
          segmentId: row.id,
          assetId: row.assetId,
          startMs: row.startMs,
          endMs: row.endMs,
          content: content,
          score: exact
              ? 1
              : (cjkPhrase
                    ? normalized.runes.length / (lower.runes.length + 1)
                    : tokens.length / (lower.length + 1)),
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList(growable: false);
  }

  bool _isCjkPhrase(String value) =>
      RegExp(r'[\u3400-\u9fff]').hasMatch(value);

  bool _containsCharactersInOrder(String content, String query) {
    var searchFrom = 0;
    for (final rune in query.runes) {
      if (rune <= 0x20) continue;
      final index = content.indexOf(String.fromCharCode(rune), searchFrom);
      if (index < 0) return false;
      searchFrom = index + 1;
    }
    return true;
  }
}
