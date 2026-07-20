import '../../data/intelligence/embedding_repository.dart';
import '../../data/intelligence/intelligence_models.dart';
import 'ai_provider.dart';
import 'transcript_service.dart';

class SemanticEmbeddingHit {
  const SemanticEmbeddingHit({
    required this.assetId,
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    required this.snippet,
    required this.score,
  });

  final String assetId;
  final String segmentId;
  final int startMs;
  final int endMs;
  final String snippet;
  final double score;
}

/// Builds and queries text embeddings without coupling the index to the
/// existing media database.
class EmbeddingIndexService {
  EmbeddingIndexService({
    required this.provider,
    required this.embeddings,
    required this.transcripts,
  });

  final AiProvider provider;
  final EmbeddingRepository embeddings;
  final TranscriptService transcripts;

  Future<int> indexAsset(String assetId, {required String model}) async {
    final segments = await transcripts.getByAsset(assetId);
    var count = 0;
    for (final segment in segments) {
      final text = segment.text.trim();
      if (text.isEmpty) continue;
      final vector = await provider.embed(text: text, model: model);
      if (vector.isEmpty) continue;
      await embeddings.upsert(
        id: '$assetId:${segment.id}:$model',
        assetId: assetId,
        segmentId: segment.id,
        model: model,
        vector: vector,
      );
      count++;
    }
    return count;
  }

  Future<List<SemanticEmbeddingHit>> search(
    String query, {
    required String model,
    int limit = 24,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final vector = await provider.embed(text: normalized, model: model);
    final candidates = await embeddings.search(
      model: model,
      vector: vector,
      limit: limit,
    );
    final byAsset = <String, List<TranscriptSegment>>{};
    final hits = <SemanticEmbeddingHit>[];
    for (final candidate in candidates) {
      final segments = byAsset.putIfAbsent(
        candidate.assetId,
        () => <TranscriptSegment>[],
      );
      if (segments.isEmpty) {
        segments.addAll(await transcripts.getByAsset(candidate.assetId));
      }
      final segment = segments.firstWhere(
        (value) => value.id == candidate.segmentId,
        orElse: () => const TranscriptSegment(
          id: '',
          assetId: '',
          startMs: 0,
          endMs: 0,
          text: '',
          language: '',
        ),
      );
      if (segment.id.isEmpty) continue;
      hits.add(
        SemanticEmbeddingHit(
          assetId: candidate.assetId,
          segmentId: candidate.segmentId,
          startMs: segment.startMs,
          endMs: segment.endMs,
          snippet: segment.translatedText?.trim().isNotEmpty == true
              ? segment.translatedText!
              : segment.text,
          score: candidate.score,
        ),
      );
    }
    return hits;
  }
}
