import '../../data/models/episode.dart';
import '../../data/models/media.dart';
import '../../data/repositories/episode_repository.dart';
import '../../data/repositories/media_repository.dart';
import '../metadata/intelligent_name_recognizer.dart';
import '../metadata/tmdb_metadata_service.dart';
import 'media_library_entry_factory.dart';

class LibraryMetadataSyncResult {
  const LibraryMetadataSyncResult({
    required this.requestedItems,
    required this.updatedItems,
    required this.failedItems,
  });

  final int requestedItems;
  final int updatedItems;
  final int failedItems;
}

/// Enriches library items with TMDB metadata.
///
/// Uses a multi-level strategy matching the Electron version:
/// 1. AI (Gemini) recognizes the clean title from filename/path
/// 2. Search TMDB with the AI-cleaned title
/// 3. Falls back to raw title if AI is unavailable
class LibraryMetadataSyncService {
  LibraryMetadataSyncService(
    this._repo,
    this._tmdb,
    this._recognizer, [
    this._episodeRepo,
  ]);

  final MediaRepository _repo;
  final TmdbMetadataService _tmdb;
  final IntelligentNameRecognizer _recognizer;
  final EpisodeRepository? _episodeRepo;

  Future<LibraryMetadataSyncResult> enrichByIds({
    required List<String> mediaIds,
    required String apiKey,
    String geminiApiKey = '',
  }) async {
    var updated = 0;
    var failed = 0;
    final ids = mediaIds.toSet().toList(growable: false);

    for (final id in ids) {
      final media = await _repo.getById(id);
      if (media == null) {
        failed++;
        continue;
      }

      // Step 1: Try AI recognition to get a better search title
      String? aiTitle;
      String? aiYear;
      if (geminiApiKey.isNotEmpty) {
        final recognition = await _recognizer.recognize(
          media.title,
          filePath: media.fullPath ?? media.path,
          geminiApiKey: geminiApiKey,
        );
        if (recognition != null && recognition.confidence > 0.6) {
          aiTitle = recognition.cleanTitle;
          aiYear = recognition.year;
        }
      }

      // Step 2: Search TMDB (with AI title if available, fallback to raw)
      final payload = await _tmdb.fetchMetadata(
        media,
        apiKey,
        searchTitle: aiTitle,
        searchYear: aiYear,
      );
      if (payload == null) {
        failed++;
        continue;
      }

      await _repo.upsert(
        media.copyWith(
          title: payload.title,
          year: payload.year,
          type: payload.type,
          posterPath: payload.posterPath,
          rating: payload.rating,
          detailsJson: payload.detailsJson,
        ),
      );
      updated++;
    }

    // After metadata is attached, reunite seasons that share a TMDB id but
    // were split at scan time (e.g. each `S0x.第x季` folder became its own show).
    await _repo.consolidateAllTvShows();

    return LibraryMetadataSyncResult(
      requestedItems: ids.length,
      updatedItems: updated,
      failedItems: failed,
    );
  }

  /// 手动修正匹配接口：使用给定的 TMDB ID 与类型拉取详情并重置影片数据，并根据需要补偿或清理剧集。
  Future<bool> manualMatch({
    required String mediaId,
    required int tmdbId,
    required MediaType type,
    required String apiKey,
  }) async {
    final media = await _repo.getById(mediaId);
    if (media == null) return false;

    // 获取 TMDB 详情数据
    final payload = await _tmdb.fetchDetails(media, tmdbId, type, apiKey);
    if (payload == null) return false;

    final path = media.fullPath ?? media.path;
    final updatedMedia = media.copyWith(
      title: payload.title,
      year: payload.year,
      type: payload.type,
      posterPath: payload.posterPath,
      rating: payload.rating,
      detailsJson: payload.detailsJson,
    );

    // 更新主媒体数据
    await _repo.upsert(updatedMedia);

    // 手动匹配同一 TMDB 后，把同库拆散的季合并到一条 show 上。
    if (payload.type == MediaType.tv) {
      await _repo.consolidateTvShow(updatedMedia);
    }

    // 剧集处理
    if (payload.type == MediaType.tv && _episodeRepo != null) {
      // 检查原文件名是否有剧集信息
      final entry = MediaLibraryEntryFactory.fromLocalPath(path);
      if (entry.hasEpisode) {
        final episode = entry.episode!.copyWith(
          showId: updatedMedia.id,
          id: '${updatedMedia.id}_s${entry.episode!.seasonNumber}e${entry.episode!.episodeNumber}',
        );
        await _episodeRepo.upsert(episode);
      } else {
        // 如果没有，自动生成一个默认 S01E01 剧集，以允许用户播放
        final defaultEpisode = Episode(
          id: '${updatedMedia.id}_s1e1',
          showId: updatedMedia.id,
          seasonNumber: 1,
          episodeNumber: 1,
          title: updatedMedia.title,
          path: updatedMedia.path,
          fullPath: updatedMedia.fullPath,
          dateAdded: DateTime.now().toIso8601String(),
        );
        await _episodeRepo.upsert(defaultEpisode);
      }
    } else if (payload.type == MediaType.movie && _episodeRepo != null) {
      // 若变更为电影，清除关联的所有剧集
      await _episodeRepo.deleteByShow(updatedMedia.id);
    }

    return true;
  }
}
