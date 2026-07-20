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
      if (hits.isNotEmpty) return hits;
      return _fallbackSearch(normalized, limit: limit);
    } catch (_) {
      return _fallbackSearch(normalized, limit: limit);
    }
  }

  Future<List<IntelligenceSearchHit>> _fallbackSearch(
    String query, {
    required int limit,
  }) async {
    final normalized = query.toLowerCase();
    final latinTokens = RegExp(r'[a-z0-9]+')
        .allMatches(normalized)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final cjkRunes = normalized.runes.where(_isCjk).toList(growable: false);
    final cjkTokens = <String>[];
    for (var i = 0; i + 1 < cjkRunes.length; i++) {
      cjkTokens.add(String.fromCharCodes(cjkRunes.skip(i).take(2)));
    }
    final tokens = [...latinTokens, ...cjkTokens];
    if (tokens.isEmpty) return const [];
    final rows = await _database.select(_database.transcriptSegments).get();
    final hits = <IntelligenceSearchHit>[];
    for (final row in rows) {
      final content = row.content;
      final lower = content.toLowerCase();
      final matches = tokens.where(lower.contains).length;
      final required = latinTokens.isNotEmpty
          ? latinTokens.length
          : (cjkTokens.length / 2).ceil().clamp(1, cjkTokens.length);
      if (matches < required) continue;
      hits.add(
        IntelligenceSearchHit(
          segmentId: row.id,
          assetId: row.assetId,
          startMs: row.startMs,
          endMs: row.endMs,
          content: content,
          score: matches / (lower.length + 1),
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList(growable: false);
  }

  bool _isCjk(int rune) =>
      (rune >= 0x3400 && rune <= 0x4dbf) ||
      (rune >= 0x4e00 && rune <= 0x9fff) ||
      (rune >= 0xf900 && rune <= 0xfaff);
}
