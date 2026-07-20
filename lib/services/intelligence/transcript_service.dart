import 'package:drift/drift.dart';

import '../../data/intelligence/intelligence_database.dart';
import '../../data/intelligence/intelligence_models.dart';
import 'ai_provider.dart';

class TranscriptService {
  TranscriptService(this._database);

  final IntelligenceDatabase _database;

  Future<void> saveProviderResult(
    String assetId,
    TranscriptionResult result,
  ) async {
    final now = DateTime.now().toIso8601String();
    await _database.transaction(() async {
      await (_database.delete(
        _database.transcriptSegments,
      )..where((row) => row.assetId.equals(assetId))).go();
      await _database.customStatement(
        'DELETE FROM intelligence_fts WHERE asset_id = ?',
        [assetId],
      );
      await _database.batch((batch) {
        for (var i = 0; i < result.segments.length; i++) {
          final segment = result.segments[i];
          batch.insert(
            _database.transcriptSegments,
            TranscriptSegmentsCompanion.insert(
              id: '$assetId:$i:${segment.startMs}',
              assetId: assetId,
              startMs: segment.startMs,
              endMs: segment.endMs,
              content: segment.text.trim(),
              language: Value(
                segment.language.isEmpty ? result.language : segment.language,
              ),
              confidence: Value(segment.confidence),
              speaker: Value(segment.speaker),
              createdAt: now,
            ),
            onConflict: DoUpdate(
              (_) => TranscriptSegmentsCompanion(
                endMs: Value(segment.endMs),
                content: Value(segment.text.trim()),
                language: Value(
                  segment.language.isEmpty ? result.language : segment.language,
                ),
                confidence: Value(segment.confidence),
                speaker: Value(segment.speaker),
              ),
            ),
          );
        }
      });
      for (var i = 0; i < result.segments.length; i++) {
        final segment = result.segments[i];
        final id = '$assetId:$i:${segment.startMs}';
        await _database.customStatement(
          'INSERT INTO intelligence_fts '
          '(segment_id, asset_id, start_ms, end_ms, content, translated_content, search_text) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            id,
            assetId,
            segment.startMs,
            segment.endMs,
            segment.text.trim(),
            '',
            segment.text.trim(),
          ],
        );
      }
    });
  }

  Future<List<TranscriptSegment>> getByAsset(String assetId) async {
    final rows =
        await (_database.select(_database.transcriptSegments)
              ..where((row) => row.assetId.equals(assetId))
              ..orderBy([(row) => OrderingTerm.asc(row.startMs)]))
            .get();
    return rows
        .map(
          (row) => TranscriptSegment(
            id: row.id,
            assetId: row.assetId,
            startMs: row.startMs,
            endMs: row.endMs,
            text: row.content,
            language: row.language,
            translatedText: row.translatedText,
            confidence: row.confidence,
            speaker: row.speaker,
            createdAt: DateTime.tryParse(row.createdAt),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveTranslations(
    String assetId,
    TranslationResult result,
  ) async {
    final rows = await getByAsset(assetId);
    await _database.transaction(() async {
      for (var i = 0; i < rows.length; i++) {
        final translated = i < result.texts.length
            ? result.texts[i].trim()
            : null;
        await (_database.update(
          _database.transcriptSegments,
        )..where((row) => row.id.equals(rows[i].id))).write(
          TranscriptSegmentsCompanion(translatedText: Value(translated)),
        );
        await _database.customStatement(
          'UPDATE intelligence_fts SET translated_content = ? WHERE segment_id = ?',
          [translated ?? '', rows[i].id],
        );
      }
    });
  }

  String toSrt(
    Iterable<TranscriptSegment> segments, {
    bool translated = false,
  }) {
    final output = StringBuffer();
    var index = 1;
    for (final segment in segments) {
      final text = translated && segment.translatedText?.isNotEmpty == true
          ? segment.translatedText!
          : segment.text;
      if (text.trim().isEmpty || segment.endMs <= segment.startMs) continue;
      output
        ..writeln(index++)
        ..writeln(
          '${_timestamp(segment.startMs)} --> ${_timestamp(segment.endMs)}',
        )
        ..writeln(text.trim())
        ..writeln();
    }
    return output.toString();
  }

  String toVtt(
    Iterable<TranscriptSegment> segments, {
    bool translated = false,
  }) {
    final output = StringBuffer('WEBVTT\n\n');
    for (final segment in segments) {
      final text = translated && segment.translatedText?.isNotEmpty == true
          ? segment.translatedText!
          : segment.text;
      if (text.trim().isEmpty || segment.endMs <= segment.startMs) continue;
      output
        ..writeln(
          '${_vttTimestamp(segment.startMs)} --> ${_vttTimestamp(segment.endMs)}',
        )
        ..writeln(text.trim())
        ..writeln();
    }
    return output.toString();
  }

  String _timestamp(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds.clamp(0, 1 << 31));
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))},${three(duration.inMilliseconds.remainder(1000))}';
  }

  String _vttTimestamp(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds.clamp(0, 1 << 31));
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}.${three(duration.inMilliseconds.remainder(1000))}';
  }
}
