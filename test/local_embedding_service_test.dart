import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/local_embedding_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test('ranks related transcript lines with offline embeddings', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final transcripts = TranscriptService(database);
    await transcripts.saveProviderResult(
      'asset-embed',
      const TranscriptionResult(
        language: 'zh-CN',
        segments: [
          ProviderTranscriptSegment(
            startMs: 1000,
            endMs: 2500,
            text: '他在雨夜的长安城门等待朋友',
          ),
          ProviderTranscriptSegment(
            startMs: 9000,
            endMs: 11000,
            text: '厨房里正在准备晚饭',
          ),
        ],
      ),
    );

    final embeddings = LocalEmbeddingService(database, transcripts);
    final written = await embeddings.rebuildFromTranscripts('asset-embed');
    expect(written, 2);

    final hits = await embeddings.search('雨夜 长安');
    expect(hits, isNotEmpty);
    expect(hits.first.assetId, 'asset-embed');
  });
}
