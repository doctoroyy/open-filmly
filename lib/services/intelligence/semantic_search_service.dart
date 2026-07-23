import '../../data/intelligence/intelligence_asset_repository.dart';
import '../../data/intelligence/intelligence_models.dart';
import '../../data/intelligence/intelligence_search_repository.dart';
import '../../data/models/media.dart';
import '../../data/repositories/media_repository.dart';
import 'content_segment_service.dart';
import 'local_embedding_service.dart';
import 'transcript_service.dart';

class AskFilmlyResult {
  const AskFilmlyResult({
    required this.title,
    required this.snippet,
    required this.reason,
    required this.score,
    this.mediaId,
    this.uri,
    this.assetId,
    this.startMs,
    this.endMs,
    this.year,
  });

  final String title;
  final String snippet;
  final String reason;
  final double score;
  final String? mediaId;
  final String? uri;
  final String? assetId;
  final int? startMs;
  final int? endMs;
  final String? year;

  bool get isScene => uri != null && startMs != null;
}

class SemanticSearchService {
  SemanticSearchService({
    required this.mediaRepository,
    required this.assets,
    required this.transcriptSearch,
    this.transcripts,
    this.contentSegments,
    this.embeddings,
  });

  final MediaRepository mediaRepository;
  final IntelligenceAssetRepository assets;
  final IntelligenceSearchRepository transcriptSearch;
  final TranscriptService? transcripts;
  final ContentSegmentService? contentSegments;
  final LocalEmbeddingService? embeddings;

  Future<List<AskFilmlyResult>> search(String query, {int limit = 24}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final output = <AskFilmlyResult>[];
    final media = await mediaRepository.search(normalized, limit: limit);
    output.addAll(
      media.map(
        (item) => AskFilmlyResult(
          title: item.title,
          year: item.year,
          mediaId: item.id,
          snippet: item.overview ?? '',
          reason: '媒体库元数据匹配',
          score: _mediaMatchScore(item, normalized),
        ),
      ),
    );

    final sceneHits = await transcriptSearch.search(normalized, limit: limit);
    for (final hit in sceneHits) {
      output.add(
        await _sceneResult(
          assetId: hit.assetId,
          startMs: hit.startMs,
          endMs: hit.endMs,
          snippet: hit.content,
          reason: '对白时间轴匹配',
          score: 2 + hit.score,
        ),
      );
    }

    final segmentHits = await contentSegments?.search(normalized, limit: limit);
    if (segmentHits != null) {
      for (final hit in segmentHits) {
        output.add(
          await _sceneResult(
            assetId: hit.assetId,
            startMs: hit.startMs,
            endMs: hit.endMs,
            snippet: hit.summary.isNotEmpty ? hit.summary : hit.searchText,
            reason: hit.title.startsWith('Scene')
                ? '场景分段匹配'
                : '结构标记 · ${hit.title}',
            score: hit.title.contains('Intro') || hit.title.contains('End')
                ? 3.5
                : 3.2,
          ),
        );
      }
    }

    final embeddingHits = await embeddings?.search(normalized, limit: limit);
    if (embeddingHits != null && transcripts != null) {
      for (final hit in embeddingHits) {
        final segments = await transcripts!.getByAsset(hit.assetId);
        TranscriptSegment? segment;
        for (final candidate in segments) {
          if (candidate.id == hit.segmentId) {
            segment = candidate;
            break;
          }
        }
        if (segment == null) continue;
        output.add(
          await _sceneResult(
            assetId: hit.assetId,
            startMs: segment.startMs,
            endMs: segment.endMs,
            snippet: segment.text,
            reason: '语义近似匹配',
            score: 1.5 + hit.score * 4,
          ),
        );
      }
    }

    output.sort((a, b) => b.score.compareTo(a.score));
    return _dedupe(output).take(limit).toList(growable: false);
  }

  Future<AskFilmlyResult> _sceneResult({
    required String assetId,
    required int startMs,
    required int endMs,
    required String snippet,
    required String reason,
    required double score,
  }) async {
    final asset = await assets.getById(assetId);
    final mediaItem = asset?.mediaId == null
        ? null
        : await mediaRepository.getById(asset!.mediaId!);
    return AskFilmlyResult(
      title: mediaItem?.title ?? _fileTitle(asset?.canonicalUri ?? assetId),
      year: mediaItem?.year,
      mediaId: asset?.mediaId,
      uri: asset?.canonicalUri,
      assetId: assetId,
      startMs: startMs,
      endMs: endMs,
      snippet: snippet,
      reason: reason,
      score: score,
    );
  }

  List<AskFilmlyResult> _dedupe(List<AskFilmlyResult> items) {
    final seen = <String>{};
    final output = <AskFilmlyResult>[];
    for (final item in items) {
      final key = [
        item.mediaId ?? item.uri ?? item.title,
        item.startMs?.toString() ?? 'title',
        item.snippet,
      ].join('|');
      if (!seen.add(key)) continue;
      output.add(item);
    }
    return output;
  }

  String _fileTitle(String uri) {
    final withoutQuery = uri.split('?').first;
    final slash = withoutQuery.lastIndexOf('/');
    final name = slash >= 0 ? withoutQuery.substring(slash + 1) : withoutQuery;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  double _mediaMatchScore(Media item, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final title = item.title.trim().toLowerCase();
    if (title == normalizedQuery) return 10;
    if (title.startsWith(normalizedQuery)) return 9;
    if (title.contains(normalizedQuery)) return 8;

    final overview = (item.overview ?? '').toLowerCase();
    if (overview.contains(normalizedQuery)) return 4;
    return 1;
  }
}
