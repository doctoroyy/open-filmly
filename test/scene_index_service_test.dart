import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/content_segment_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/scene_index_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test(
    'builds searchable time-window scenes from transcript segments',
    () async {
      final database = IntelligenceDatabase.inMemory();
      addTearDown(database.close);
      final transcripts = TranscriptService(database);
      await transcripts.saveProviderResult(
        'asset-1',
        const TranscriptionResult(
          language: 'en',
          segments: [
            ProviderTranscriptSegment(startMs: 0, endMs: 1000, text: 'rain'),
            ProviderTranscriptSegment(
              startMs: 2000,
              endMs: 3000,
              text: 'at night',
            ),
            ProviderTranscriptSegment(
              startMs: 70000,
              endMs: 71000,
              text: 'mountain',
            ),
          ],
        ),
      );

      final service = SceneIndexService(
        transcripts,
        ContentSegmentRepository(database),
      );
      expect(await service.indexAsset('asset-1'), 2);
      final hits = await ContentSegmentRepository(database).search('rain');

      expect(hits, hasLength(1));
      expect(hits.single.startMs, 0);
      expect(hits.single.summary, contains('at night'));
    },
  );
}
