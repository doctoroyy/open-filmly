import 'dart:convert';

import '../../data/models/app_config.dart';
import '../../data/models/media.dart';
import '../../data/repositories/episode_repository.dart';
import '../../data/repositories/media_repository.dart';
import 'library_metadata_sync_service.dart';
import 'library_scanner_service.dart';
import 'media_library_entry_factory.dart';

/// Summary of an incremental auto-scan run.
class AutoScanResult {
  const AutoScanResult({
    required this.scannedFiles,
    required this.importedItems,
    required this.enrichedItems,
    required this.retitledItems,
    required this.skipped,
  });

  const AutoScanResult.skipped({this.retitledItems = 0})
    : scannedFiles = 0,
      importedItems = 0,
      enrichedItems = 0,
      skipped = true;

  final int scannedFiles;
  final int importedItems;
  final int enrichedItems;

  /// Existing entries whose dirty release-name titles were re-derived.
  final int retitledItems;
  final bool skipped;

  bool get hasChanges =>
      importedItems > 0 || enrichedItems > 0 || retitledItems > 0;
}

/// Performs an incremental library refresh on app startup.
///
/// Unlike the manual "scan all" flow, this does NOT clear the library first.
/// It re-derives titles for entries that predate the current cleanup rules,
/// re-scans configured folders (upsert is idempotent, so existing items are
/// refreshed rather than duplicated) and then enriches only items that are
/// still missing posters, keeping startup fast and the network footprint low.
class LibraryAutoScanService {
  LibraryAutoScanService(
    this._scanner,
    this._metadataSync,
    this._repo, [
    this._episodeRepo,
  ]);

  final LibraryScannerService _scanner;
  final LibraryMetadataSyncService _metadataSync;
  final MediaRepository _repo;
  final EpisodeRepository? _episodeRepo;

  Future<AutoScanResult> run(AppConfig config) async {
    // Hygiene pass first: drop OS-junk rows (macOS `._` sidecars etc.) and
    // re-derive dirty titles. Runs even when no local folders are set, so it
    // also cleans SMB/WebDAV imports.
    final purged = await _purgeJunk();
    final fakeEps = await _purgeFakeEpisodes();
    final retitled = await _retitleDirtyTitles();
    // Reunite TV seasons that older parsers split into one-show-per-season
    // (e.g. `S01.第一季` → title "S01"). Safe / idempotent.
    final repaired = await _repairSplitTvShows();

    if (!config.autoScanOnStartup || config.selectedFolders.isEmpty) {
      return AutoScanResult.skipped(
        retitledItems: retitled + purged + fakeEps + repaired,
      );
    }

    final scanResult = await _scanner.scanFolders(config.selectedFolders);

    var enriched = 0;
    if (config.tmdbApiKey.isNotEmpty) {
      final missing = await _repo.getIdsWithoutPoster();
      if (missing.isNotEmpty) {
        final syncResult = await _metadataSync.enrichByIds(
          mediaIds: missing,
          apiKey: config.tmdbApiKey,
          geminiApiKey: config.geminiApiKey,
        );
        enriched = syncResult.updatedItems;
      }
    } else if (repaired > 0) {
      // Even without TMDB, re-run title-based consolidation after repair.
      await _repo.consolidateAllTvShows();
    }

    return AutoScanResult(
      scannedFiles: scanResult.scannedFiles,
      importedItems: scanResult.importedItems,
      enrichedItems: enriched,
      retitledItems: retitled + purged + fakeEps + repaired,
      skipped: false,
    );
  }

  /// Removes rows whose source path is OS junk (e.g. macOS `._` AppleDouble
  /// sidecars) that earlier scans imported as phantom duplicates.
  Future<int> _purgeJunk() async {
    final items = await _repo.browse();
    var purged = 0;
    for (final media in items) {
      final path = media.fullPath ?? media.path;
      if (path.isNotEmpty && MediaLibraryEntryFactory.isJunkPath(path)) {
        await _repo.deleteById(media.id);
        purged++;
      }
    }
    return purged;
  }

  /// Drops placeholder episodes whose path is a media id (`tv:smb:…`) rather
  /// than a real video file — leftovers from older default-episode injection
  /// and show consolidation.
  Future<int> _purgeFakeEpisodes() async {
    final episodeRepo = _episodeRepo;
    if (episodeRepo == null) return 0;
    final shows = await _repo.browse(type: MediaType.tv);
    var removed = 0;
    for (final show in shows) {
      final episodes = await episodeRepo.getByShow(show.id);
      for (final episode in episodes) {
        final path = (episode.path).trim();
        final full = (episode.fullPath ?? '').trim();
        final looksFake =
            path.startsWith('tv:') ||
            full.startsWith('tv:') ||
            (!MediaLibraryEntryFactory.isVideoPath(path) &&
                !path.startsWith('smb://') &&
                !path.startsWith('/') &&
                !MediaLibraryEntryFactory.isVideoPath(full) &&
                !full.startsWith('smb://') &&
                !full.startsWith('/'));
        if (!looksFake) continue;
        await episodeRepo.deleteById(episode.id);
        removed++;
      }
    }
    return removed;
  }

  /// Re-derives titles from filenames for entries without TMDB metadata, so
  /// items imported before the current cleanup rules pick them up. TV shows
  /// are skipped (their titles derive from directory names, and enriched
  /// entries already carry curated TMDB titles).
  Future<int> _retitleDirtyTitles() async {
    final items = await _repo.browse();
    var changed = 0;
    for (final media in items) {
      if (media.tmdbId != null) continue;
      if (media.type == MediaType.tv) continue;
      // Only touch titles that visibly carry release-name noise — manual or
      // already-clean titles stay exactly as the user left them.
      if (!MediaLibraryEntryFactory.titleLooksDirty(media.title)) continue;
      final path = media.fullPath ?? media.path;
      if (path.isEmpty) continue;

      final fresh = MediaLibraryEntryFactory.fromLocalPath(path).media;
      if (fresh.title.isNotEmpty && fresh.title != media.title) {
        await _repo.upsert(
          media.copyWith(
            title: fresh.title,
            year: media.year.isEmpty ? fresh.year : media.year,
          ),
        );
        changed++;
      }
    }
    return changed;
  }

  /// Rebuilds TV show titles from episode file paths when the stored title is
  /// a season token (`S05`) or the stored fullPath still points at a season
  /// folder (`…/S01.第一季`). Then consolidates by title / TMDB id.
  Future<int> _repairSplitTvShows() async {
    final episodeRepo = _episodeRepo;
    if (episodeRepo == null) {
      return _repo.consolidateAllTvShows();
    }

    final shows = await _repo.browse(type: MediaType.tv);
    var retitled = 0;
    for (final show in shows) {
      final episodes = await episodeRepo.getByShow(show.id);
      if (episodes.isEmpty) continue;

      String? recoveredTitle;
      for (final episode in episodes) {
        final candidatePath = _logicalMediaPath(
          episode.fullPath ?? episode.path,
        );
        if (candidatePath.isEmpty) continue;
        final parsed = MediaLibraryEntryFactory.fromLocalPath(candidatePath);
        if (parsed.media.type != MediaType.tv) continue;
        if (parsed.media.title.isEmpty) continue;
        if (_isWeakSeasonTitle(parsed.media.title)) continue;
        recoveredTitle = parsed.media.title;
        break;
      }
      if (recoveredTitle == null || recoveredTitle == show.title) continue;

      // Path is authoritative when the old parser left a season folder as the
      // show root (fullPath like `…/S01.第一季`) or the title is a season token.
      // That also corrects wrong TMDB matches such as "S01" → random other show.
      final pathLooksSplit = _looksLikeSeasonFullPath(show.fullPath ?? '');
      final needsRetitle =
          _isWeakSeasonTitle(show.title) ||
          pathLooksSplit ||
          show.tmdbId == null;
      if (!needsRetitle) continue;

      final dropStaleMatch = pathLooksSplit || _isWeakSeasonTitle(show.title);
      await _repo.upsert(
        Media(
          id: show.id,
          title: recoveredTitle,
          year: show.year,
          type: show.type,
          path: show.path,
          fullPath: show.fullPath,
          // Drop stale poster/rating when the filesystem says this row was a
          // mis-split season; a sibling with the real match will donate them
          // during consolidate, otherwise enrichment re-fetches.
          posterPath: dropStaleMatch ? null : show.posterPath,
          rating: dropStaleMatch ? null : show.rating,
          detailsJson: dropStaleMatch
              ? _detailsWithoutTmdb(show.detailsJson)
              : show.detailsJson,
          fileHash: show.fileHash,
          dateAdded: show.dateAdded,
          lastUpdated: show.lastUpdated,
          isFavorite: show.isFavorite,
        ),
      );
      retitled++;
    }

    final merged = await _repo.consolidateAllTvShows();
    return retitled + merged;
  }

  static bool _isWeakSeasonTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return true;
    return RegExp(
      r'^(?:s\d{1,2}|season\s*\d+|第[一二三四五六七八九十百\d]+季)$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static bool _looksLikeSeasonFullPath(String path) {
    final name = path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
    return RegExp(
      r'^(?:s\d{1,2}(?:[.\-_\s].*)?|season\s*\d+|第[一二三四五六七八九十百\d]+季)$',
      caseSensitive: false,
    ).hasMatch(name);
  }

  /// Normalizes local / smb / webdav paths into a slash path the local factory
  /// can parse for title extraction.
  static String _logicalMediaPath(String raw) {
    var path = raw.trim();
    if (path.isEmpty) return '';
    if (path.startsWith('smb://')) {
      final withoutScheme = path.substring('smb://'.length);
      final slash = withoutScheme.indexOf('/');
      path = slash >= 0 ? withoutScheme.substring(slash) : withoutScheme;
    } else if (path.startsWith('webdav://') || path.startsWith('https://')) {
      try {
        final uri = Uri.parse(path);
        path = uri.path;
      } catch (_) {}
    }
    if (!path.startsWith('/')) path = '/$path';
    return path;
  }

  /// Keeps playback `source` (and other non-TMDB fields) while clearing the
  /// mismatched tmdbId / overview / artwork that belonged to a wrong match.
  static String? _detailsWithoutTmdb(String? raw) {
    if (raw == null || raw.isEmpty) return raw;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return raw;
      final map = Map<String, dynamic>.from(decoded);
      map.remove('tmdbId');
      map.remove('overview');
      map.remove('backdrop_path');
      map.remove('release_date');
      map.remove('genres');
      return jsonEncode(map);
    } catch (_) {
      return raw;
    }
  }
}
