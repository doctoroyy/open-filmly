import 'package:drift/drift.dart';

import 'intelligence_database.dart';

class ContentSegmentSearchHit {
  const ContentSegmentSearchHit({
    required this.assetId,
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.summary,
    required this.score,
  });

  final String assetId;
  final int startMs;
  final int endMs;
  final String title;
  final String summary;
  final double score;
}

class ContentSegmentRepository {
  ContentSegmentRepository(this._database);

  final IntelligenceDatabase _database;

  Future<void> replaceForAsset(
    String assetId,
    Iterable<ContentSegmentsCompanion> segments,
  ) async {
    await (_database.delete(
      _database.contentSegments,
    )..where((row) => row.assetId.equals(assetId))).go();
    await _database.batch((batch) {
      for (final segment in segments) {
        batch.insert(
          _database.contentSegments,
          segment,
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<Map<String, String>> screenshotPathsForAsset(String assetId) async {
    final rows = await (_database.select(
      _database.contentSegments,
    )..where((row) => row.assetId.equals(assetId))).get();
    return {
      for (final row in rows)
        if (row.screenshotPath?.trim().isNotEmpty == true)
          row.id: row.screenshotPath!,
    };
  }

  Future<List<ContentSegmentSearchHit>> search(
    String query, {
    int limit = 24,
  }) async {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) return const [];
    final rows = await _database.select(_database.contentSegments).get();
    final hits = <ContentSegmentSearchHit>[];
    for (final row in rows) {
      final haystack = '${row.title} ${row.summary} ${row.searchText}'
          .toLowerCase();
      final matches = terms.where(haystack.contains).length;
      if (matches == 0) continue;
      hits.add(
        ContentSegmentSearchHit(
          assetId: row.assetId,
          startMs: row.startMs,
          endMs: row.endMs,
          title: row.title,
          summary: row.summary,
          score: matches / terms.length,
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList(growable: false);
  }

  Future<void> attachScreenshots(String assetId, Iterable<String> paths) async {
    final normalized = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) return;
    final rows =
        await (_database.select(_database.contentSegments)
              ..where((row) => row.assetId.equals(assetId))
              ..orderBy([(row) => OrderingTerm.asc(row.startMs)]))
            .get();
    for (var i = 0; i < rows.length && i < normalized.length; i++) {
      await (_database.update(
        _database.contentSegments,
      )..where((row) => row.id.equals(rows[i].id))).write(
        ContentSegmentsCompanion(screenshotPath: Value(normalized[i])),
      );
    }
  }
}
