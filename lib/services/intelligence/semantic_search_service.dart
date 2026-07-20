import '../../data/intelligence/intelligence_asset_repository.dart';
import '../../data/intelligence/intelligence_search_repository.dart';
import '../../data/repositories/media_repository.dart';

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
  });

  final MediaRepository mediaRepository;
  final IntelligenceAssetRepository assets;
  final IntelligenceSearchRepository transcriptSearch;

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
          score: 1,
        ),
      ),
    );

    final sceneHits = await transcriptSearch.search(normalized, limit: limit);
    for (final hit in sceneHits) {
      final asset = await assets.getById(hit.assetId);
      if (asset == null) continue;
      final mediaItem = asset.mediaId == null
          ? null
          : await mediaRepository.getById(asset.mediaId!);
      output.add(
        AskFilmlyResult(
          title: mediaItem?.title ?? _fileTitle(asset.canonicalUri),
          year: mediaItem?.year,
          mediaId: asset.mediaId,
          uri: asset.canonicalUri,
          assetId: hit.assetId,
          startMs: hit.startMs,
          endMs: hit.endMs,
          snippet: hit.content,
          reason: '对白时间轴匹配',
          score: 2 + hit.score,
        ),
      );
    }

    output.sort((a, b) => b.score.compareTo(a.score));
    return output.take(limit).toList(growable: false);
  }

  String _fileTitle(String uri) {
    final withoutQuery = uri.split('?').first;
    final slash = withoutQuery.lastIndexOf('/');
    final name = slash >= 0 ? withoutQuery.substring(slash + 1) : withoutQuery;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
