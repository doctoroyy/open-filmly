import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/embedding_repository.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/embedding_index_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test('persists vectors and returns the closest segment first', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final repository = EmbeddingRepository(database);

    await repository.upsert(
      id: 'asset-a:segment-a:model-a',
      assetId: 'asset-a',
      segmentId: 'segment-a',
      model: 'model-a',
      vector: const [1, 0],
    );
    await repository.upsert(
      id: 'asset-a:segment-b:model-a',
      assetId: 'asset-a',
      segmentId: 'segment-b',
      model: 'model-a',
      vector: const [0, 1],
    );

    final hits = await repository.search(
      model: 'model-a',
      vector: const [0.9, 0.1],
    );

    expect(hits.first.segmentId, 'segment-a');
    expect(hits.first.score, closeTo(0.99, 0.02));
  });

  test('indexes transcript segments through the configured provider', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final transcripts = TranscriptService(database);
    await transcripts.saveProviderResult(
      'asset-a',
      const TranscriptionResult(
        language: 'en',
        segments: [
          ProviderTranscriptSegment(
            startMs: 0,
            endMs: 1000,
            text: 'rain over the city',
          ),
        ],
      ),
    );
    final provider = FakeEmbeddingProvider();
    final service = EmbeddingIndexService(
      provider: provider,
      embeddings: EmbeddingRepository(database),
      transcripts: transcripts,
    );

    final count = await service.indexAsset('asset-a', model: 'model-a');

    expect(count, 1);
    expect(provider.inputs, ['rain over the city']);
    final hits = await service.search('city', model: 'model-a');
    expect(hits.single.segmentId, 'asset-a:0:0');
  });
}

class FakeEmbeddingProvider implements AiProvider {
  final inputs = <String>[];

  @override
  String get id => 'fake';

  @override
  Future<Map<String, dynamic>> probe(
    String path, {
    void Function(double progress)? onProgress,
  }) => Future.value(const {});

  @override
  Future<TranscriptionResult> transcribe({
    required String path,
    required String language,
    required String model,
    void Function(double progress)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<TranslationResult> translate({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
    required String model,
    void Function(double progress)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<List<String>> sampleFrames({
    required String path,
    required String outputDirectory,
    required int durationMs,
    int count = 12,
    void Function(double progress)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<List<double>> embed({
    required String text,
    required String model,
  }) async {
    inputs.add(text);
    return text.contains('city') ? const [1, 0] : const [0, 1];
  }
}
