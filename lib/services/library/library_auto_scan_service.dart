import '../../data/models/app_config.dart';
import '../../data/models/media.dart';
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
  LibraryAutoScanService(this._scanner, this._metadataSync, this._repo);

  final LibraryScannerService _scanner;
  final LibraryMetadataSyncService _metadataSync;
  final MediaRepository _repo;

  Future<AutoScanResult> run(AppConfig config) async {
    // Hygiene pass first: drop OS-junk rows (macOS `._` sidecars etc.) and
    // re-derive dirty titles. Runs even when no local folders are set, so it
    // also cleans SMB/WebDAV imports.
    final purged = await _purgeJunk();
    final retitled = await _retitleDirtyTitles();

    if (!config.autoScanOnStartup || config.selectedFolders.isEmpty) {
      return AutoScanResult.skipped(retitledItems: retitled + purged);
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
    }

    return AutoScanResult(
      scannedFiles: scanResult.scannedFiles,
      importedItems: scanResult.importedItems,
      enrichedItems: enriched,
      retitledItems: retitled + purged,
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
}
