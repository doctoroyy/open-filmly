import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/content_segment_service.dart';
import 'package:open_filmly/services/intelligence/smart_skip_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test('exposes intro skip markers from classified content segments', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final transcripts = TranscriptService(database);
    await transcripts.saveProviderResult(
      'asset-skip',
      const TranscriptionResult(
        language: 'zh-CN',
        segments: [
          ProviderTranscriptSegment(
            startMs: 0,
            endMs: 40000,
            text: '前情提要 上回说到',
          ),
          ProviderTranscriptSegment(
            startMs: 50000,
            endMs: 55000,
            text: '正片开始',
          ),
        ],
      ),
    );
    final content = ContentSegmentService(database, transcripts);
    await content.rebuildFromTranscripts('asset-skip');
    final service = SmartSkipService(content);
    final markers = await service.markersFor('asset-skip');
    expect(markers, isNotEmpty);
    expect(markers.first.label, contains('跳过'));
    final active = service.activeMarker(markers: markers, positionMs: 1000);
    expect(active, isNotNull);
  });
}
