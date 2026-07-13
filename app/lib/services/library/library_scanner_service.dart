import 'dart:io';

import '../../data/models/media.dart';
import '../../data/repositories/episode_repository.dart';
import '../../data/repositories/media_repository.dart';
import 'media_library_entry_factory.dart';

/// Summary returned after scanning one or more configured folders.
class LibraryScanResult {
  const LibraryScanResult({
    required this.scannedFiles,
    required this.importedItems,
    required this.movieCount,
    required this.tvCount,
    required this.episodeCount,
    required this.missingFolders,
    required this.mediaIds,
  });

  final int scannedFiles;
  final int importedItems;
  final int movieCount;
  final int tvCount;
  final int episodeCount;
  final int missingFolders;
  final List<String> mediaIds;
}

/// Scans local folders for video files and imports them into the media library.
///
/// TV shows are split into a parent show entry (in the media table) plus
/// individual episodes (in the episodes table).
class LibraryScannerService {
  LibraryScannerService(this._repo, [this._episodeRepo]);

  final MediaRepository _repo;
  final EpisodeRepository? _episodeRepo;

  Future<LibraryScanResult> scanFolders(List<String> folders) async {
    final roots = folders
        .map((folder) => folder.trim())
        .where((folder) => folder.isNotEmpty)
        .toSet();

    var scannedFiles = 0;
    var importedItems = 0;
    var movieCount = 0;
    var tvCount = 0;
    var episodeCount = 0;
    var missingFolders = 0;
    final mediaIds = <String>[];
    final scannedShows = <String, Media>{};

    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) {
        missingFolders++;
        continue;
      }

      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File ||
            !MediaLibraryEntryFactory.isImportableVideo(entity.path)) {
          continue;
        }

        scannedFiles++;
        final entry = MediaLibraryEntryFactory.fromLocalPath(entity.path);
        await _repo.upsertScanned(entry.media);
        importedItems++;
        mediaIds.add(entry.media.id);

        if (entry.hasEpisode && _episodeRepo != null) {
          await _episodeRepo.upsert(entry.episode!);
          episodeCount++;
        }

        switch (entry.media.type) {
          case MediaType.movie:
            movieCount++;
            break;
          case MediaType.tv:
            tvCount++;
            scannedShows[entry.media.id] = entry.media;
            break;
          case MediaType.unknown:
            break;
        }
      }
    }

    for (final show in scannedShows.values) {
      await _repo.consolidateTvShow(show);
    }

    return LibraryScanResult(
      scannedFiles: scannedFiles,
      importedItems: importedItems,
      movieCount: movieCount,
      tvCount: tvCount,
      episodeCount: episodeCount,
      missingFolders: missingFolders,
      mediaIds: mediaIds,
    );
  }
}
