import 'package:drift/drift.dart';

import '../../data/intelligence/intelligence_database.dart';
import '../../data/intelligence/intelligence_models.dart';
import 'transcript_service.dart';

/// Builds timeline-aware content segments from transcripts so search and
/// Companion can reason about scenes rather than isolated lines.
class ContentSegmentService {
  ContentSegmentService(this._database, this._transcripts);

  final IntelligenceDatabase _database;
  final TranscriptService _transcripts;

  /// Groups nearby transcript lines into scene-sized content segments and
  /// marks likely intro / outro / recap windows with searchable labels.
  Future<List<ContentSegment>> rebuildFromTranscripts(String assetId) async {
    final lines = await _transcripts.getByAsset(assetId);
    if (lines.isEmpty) {
      await _clear(assetId);
      return const [];
    }

    final durationMs = lines.map((line) => line.endMs).fold<int>(0, _max);
    final chunks = _chunkLines(lines);
    final segments = <ContentSegment>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final startMs = chunk.first.startMs;
      final endMs = chunk.last.endMs;
      final text = chunk.map((line) => line.text.trim()).where((t) => t.isNotEmpty).join(' ');
      final kind = _classifyWindow(
        startMs: startMs,
        endMs: endMs,
        durationMs: durationMs,
        text: text,
        index: i,
        total: chunks.length,
      );
      final title = kind ?? 'Scene ${i + 1}';
      final summary = text.length <= 180 ? text : '${text.substring(0, 180)}…';
      segments.add(
        ContentSegment(
          id: '$assetId:scene:$i:$startMs',
          assetId: assetId,
          startMs: startMs,
          endMs: endMs,
          title: title,
          summary: summary,
          searchText: '$title $text',
          themesJson: kind == null ? null : '["$kind"]',
          createdAt: DateTime.now(),
        ),
      );
    }

    await _database.transaction(() async {
      await _clear(assetId);
      await _database.batch((batch) {
        for (final segment in segments) {
          batch.insert(
            _database.contentSegments,
            ContentSegmentsCompanion.insert(
              id: segment.id,
              assetId: segment.assetId,
              startMs: segment.startMs,
              endMs: segment.endMs,
              title: Value(segment.title),
              summary: Value(segment.summary),
              peopleJson: Value(segment.peopleJson),
              placesJson: Value(segment.placesJson),
              themesJson: Value(segment.themesJson),
              screenshotPath: Value(segment.screenshotPath),
              searchText: Value(segment.searchText),
              createdAt: (segment.createdAt ?? DateTime.now()).toIso8601String(),
            ),
          );
        }
      });
    });
    return segments;
  }

  Future<List<ContentSegment>> listByAsset(String assetId) async {
    final rows =
        await (_database.select(_database.contentSegments)
              ..where((row) => row.assetId.equals(assetId))
              ..orderBy([(row) => OrderingTerm.asc(row.startMs)]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<List<ContentSegment>> search(String query, {int limit = 24}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final rows = await _database.select(_database.contentSegments).get();
    final hits = <ContentSegment>[];
    for (final row in rows) {
      final haystack =
          '${row.title} ${row.summary} ${row.searchText}'.toLowerCase();
      final exact = haystack.contains(normalized);
      final tokenHit =
          tokens.isNotEmpty && tokens.every((token) => haystack.contains(token));
      final cjk = _isCjk(normalized) && _containsInOrder(haystack, normalized);
      if (!exact && !tokenHit && !cjk) continue;
      hits.add(_toDomain(row));
    }
    hits.sort((a, b) => a.startMs.compareTo(b.startMs));
    return hits.take(limit).toList(growable: false);
  }

  Future<void> _clear(String assetId) async {
    await (_database.delete(
      _database.contentSegments,
    )..where((row) => row.assetId.equals(assetId))).go();
  }

  List<List<TranscriptSegment>> _chunkLines(List<TranscriptSegment> lines) {
    const gapMs = 8000;
    const maxChunkMs = 90000;
    const maxLines = 12;
    final chunks = <List<TranscriptSegment>>[];
    var current = <TranscriptSegment>[lines.first];
    for (var i = 1; i < lines.length; i++) {
      final previous = current.last;
      final next = lines[i];
      final gap = next.startMs - previous.endMs;
      final span = next.endMs - current.first.startMs;
      if (gap > gapMs || span > maxChunkMs || current.length >= maxLines) {
        chunks.add(current);
        current = [next];
      } else {
        current.add(next);
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  String? _classifyWindow({
    required int startMs,
    required int endMs,
    required int durationMs,
    required String text,
    required int index,
    required int total,
  }) {
    final lower = text.toLowerCase();
    final introKeywords = RegExp(
      r'previously on|last time|前情提要|上回|片头|opening credits|title sequence',
      caseSensitive: false,
    );
    final outroKeywords = RegExp(
      r'end credits|closing credits|to be continued|未完待续|片尾|主演|导演|出品',
      caseSensitive: false,
    );
    if (index == 0 && startMs < 180000 && introKeywords.hasMatch(lower)) {
      return 'Intro / Recap';
    }
    if (index == 0 && startMs < 90000 && endMs - startMs < 120000) {
      return 'Opening';
    }
    if (durationMs > 0 &&
        startMs > durationMs * 0.88 &&
        (outroKeywords.hasMatch(lower) || index >= total - 2)) {
      return 'End credits';
    }
    if (outroKeywords.hasMatch(lower)) return 'End credits';
    if (introKeywords.hasMatch(lower)) return 'Intro / Recap';
    return null;
  }

  ContentSegment _toDomain(ContentSegmentRow row) => ContentSegment(
    id: row.id,
    assetId: row.assetId,
    startMs: row.startMs,
    endMs: row.endMs,
    title: row.title,
    summary: row.summary,
    searchText: row.searchText,
    peopleJson: row.peopleJson,
    placesJson: row.placesJson,
    themesJson: row.themesJson,
    screenshotPath: row.screenshotPath,
    createdAt: DateTime.tryParse(row.createdAt),
  );

  bool _isCjk(String value) => RegExp(r'[\u3400-\u9fff]').hasMatch(value);

  bool _containsInOrder(String content, String query) {
    var from = 0;
    for (final rune in query.runes) {
      if (rune <= 0x20) continue;
      final index = content.indexOf(String.fromCharCode(rune), from);
      if (index < 0) return false;
      from = index + 1;
    }
    return true;
  }

  int _max(int a, int b) => a > b ? a : b;
}
