import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/content_segment_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test('builds searchable scene segments from transcript gaps', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final transcripts = TranscriptService(database);
    await transcripts.saveProviderResult(
      'asset-1',
      const TranscriptionResult(
        language: 'zh-CN',
        segments: [
          ProviderTranscriptSegment(startMs: 0, endMs: 2000, text: '片头音乐'),
          ProviderTranscriptSegment(
            startMs: 2500,
            endMs: 5000,
            text: '他在雨夜等待',
          ),
          ProviderTranscriptSegment(
            startMs: 20000,
            endMs: 23000,
            text: '后来他们重逢',
          ),
        ],
      ),
    );

    final service = ContentSegmentService(database, transcripts);
    final segments = await service.rebuildFromTranscripts('asset-1');
    expect(segments.length, greaterThanOrEqualTo(2));

    final hits = await service.search('雨夜');
    expect(hits, isNotEmpty);
    expect(hits.first.searchText, contains('雨夜'));
  });
}
