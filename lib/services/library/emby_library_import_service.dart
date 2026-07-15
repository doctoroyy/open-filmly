import '../../data/repositories/episode_repository.dart';
import '../../data/repositories/media_repository.dart';
import '../emby/emby_service.dart';
import 'media_library_entry_factory.dart';

/// Summary returned after importing an Emby/Jellyfin library.
class EmbyImportResult {
  const EmbyImportResult({
    required this.movieCount,
    required this.tvCount,
    required this.episodeCount,
    required this.mediaIds,
  });

  final int movieCount;
  final int tvCount;
  final int episodeCount;
  final List<String> mediaIds;

  int get importedItems => movieCount + tvCount;
}

/// Imports an Emby/Jellyfin server's movies and series (with episodes) into the
/// local library. Items keep an `emby` source so playback can build a stream
/// URL with a live token.
class EmbyLibraryImportService {
  EmbyLibraryImportService(this._emby, this._repo, [this._episodeRepo]);

  final EmbyService _emby;
  final MediaRepository _repo;
  final EpisodeRepository? _episodeRepo;

  Future<EmbyImportResult> importLibrary() async {
    final config = _emby.config;
    if (!_emby.isConnected || config == null) {
      throw StateError('Emby 未连接');
    }
    final base = config.url;

    var movieCount = 0;
    var tvCount = 0;
    var episodeCount = 0;
    final mediaIds = <String>[];

    final items = await _emby.fetchLibrary();
    for (final item in items) {
      if (item.id.isEmpty) continue;
      final isSeries = item.type == 'Series';
      final media = MediaLibraryEntryFactory.fromEmbyMovieOrShow(
        baseUrl: base,
        itemId: item.id,
        title: item.name,
        year: item.year,
        isSeries: isSeries,
        posterUrl: item.primaryImageTag == null
            ? null
            : _emby.imageUrl(item.id, tag: item.primaryImageTag),
        overview: item.overview,
      );
      await _repo.upsert(media);
      mediaIds.add(media.id);

      if (isSeries) {
        tvCount++;
        if (_episodeRepo != null) {
          episodeCount += await _importEpisodes(item.id, media.id);
        }
      } else {
        movieCount++;
      }
    }

    return EmbyImportResult(
      movieCount: movieCount,
      tvCount: tvCount,
      episodeCount: episodeCount,
      mediaIds: mediaIds,
    );
  }

  Future<int> _importEpisodes(String seriesId, String showMediaId) async {
    final episodes = await _emby.fetchEpisodes(seriesId);
    var count = 0;
    for (final ep in episodes) {
      if (ep.id.isEmpty) continue;
      await _episodeRepo!.upsert(
        MediaLibraryEntryFactory.fromEmbyEpisode(
          showId: showMediaId,
          itemId: ep.id,
          seasonNumber: ep.seasonNumber ?? 0,
          episodeNumber: ep.episodeNumber ?? 0,
          title: ep.name,
        ),
      );
      count++;
    }
    return count;
  }
}
