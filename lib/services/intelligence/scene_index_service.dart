import 'package:drift/drift.dart';

import '../../data/intelligence/content_segment_repository.dart';
import '../../data/intelligence/intelligence_database.dart';
import '../../data/intelligence/intelligence_models.dart';
import 'transcript_service.dart';

/// Creates deterministic time-window scenes from a transcript. This is the
/// safe baseline for search; a future vision provider can replace the title
/// and summary without changing search or playback contracts.
class SceneIndexService {
  SceneIndexService(this._transcripts, this._segments);

  final TranscriptService _transcripts;
  final ContentSegmentRepository _segments;

  Future<int> indexAsset(String assetId, {int windowMs = 60 * 1000}) async {
    final transcript = await _transcripts.getByAsset(assetId);
    final existingScreenshots = await _segments.screenshotPathsForAsset(
      assetId,
    );
    final grouped = <int, List<TranscriptSegment>>{};
    for (final segment in transcript) {
      grouped.putIfAbsent(segment.startMs ~/ windowMs, () => []).add(segment);
    }
    final companions = <ContentSegmentsCompanion>[];
    for (final entry in grouped.entries) {
      final values = entry.value;
      final startMs = values
          .map((item) => item.startMs)
          .reduce((a, b) => a < b ? a : b);
      final endMs = values
          .map((item) => item.endMs)
          .reduce((a, b) => a > b ? a : b);
      final summary = values
          .map((item) => item.text.trim())
          .where((item) => item.isNotEmpty)
          .join(' ');
      if (summary.isEmpty) continue;
      companions.add(
        ContentSegmentsCompanion.insert(
          id: '$assetId:scene:${entry.key}',
          assetId: assetId,
          startMs: startMs,
          endMs: endMs,
          title: Value('Scene ${entry.key + 1}'),
          summary: Value(summary),
          searchText: Value(summary),
          screenshotPath: Value(
            existingScreenshots['$assetId:scene:${entry.key}'],
          ),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    await _segments.replaceForAsset(assetId, companions);
    return companions.length;
  }

  Future<void> attachScreenshots(String assetId, Iterable<String> paths) =>
      _segments.attachScreenshots(assetId, paths);
}
