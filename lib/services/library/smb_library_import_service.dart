import 'package:smb_connect/smb_connect.dart';

import '../../data/models/media.dart';
import '../../data/repositories/episode_repository.dart';
import '../../data/repositories/media_repository.dart';
import '../smb/smb_service.dart';
import 'media_library_entry_factory.dart';

/// Summary returned after importing an SMB folder into the media library.
class SmbLibraryImportResult {
  const SmbLibraryImportResult({
    required this.scannedFiles,
    required this.importedItems,
    required this.movieCount,
    required this.tvCount,
    required this.episodeCount,
    required this.rootPath,
    required this.mediaIds,
  });

  final int scannedFiles;
  final int importedItems;
  final int movieCount;
  final int tvCount;
  final int episodeCount;
  final String rootPath;
  final List<String> mediaIds;
}

/// Recursively imports SMB video files from the active session into the library.
class SmbLibraryImportService {
  SmbLibraryImportService(this._smb, this._repo, [this._episodeRepo]);

  final SmbService _smb;
  final MediaRepository _repo;
  final EpisodeRepository? _episodeRepo;

  Future<SmbLibraryImportResult> importFolder(SmbFile root) async {
    final config = _smb.config;
    if (!_smb.isConnected || config == null) {
      throw StateError('SMB connection not established');
    }

    var scannedFiles = 0;
    var importedItems = 0;
    var movieCount = 0;
    var tvCount = 0;
    var episodeCount = 0;
    final mediaIds = <String>[];
    final visited = <String>{};
    final scannedShows = <String, Media>{};

    Future<void> walk(SmbFile folder) async {
      if (!visited.add(folder.path)) return;

      final entries = await _smb.listChildren(folder);
      for (final entry in entries) {
        if (entry.isDirectory()) {
          await walk(entry);
          continue;
        }
        if (!MediaLibraryEntryFactory.isImportableVideo(entry.path)) continue;

        scannedFiles++;
        final libraryEntry = MediaLibraryEntryFactory.fromSmbFile(
          config: config,
          file: entry,
        );
        await _repo.upsertScanned(libraryEntry.media);
        importedItems++;
        mediaIds.add(libraryEntry.media.id);

        if (libraryEntry.hasEpisode && _episodeRepo != null) {
          await _episodeRepo.upsert(libraryEntry.episode!);
          episodeCount++;
        }

        switch (libraryEntry.media.type) {
          case MediaType.movie:
            movieCount++;
            break;
          case MediaType.tv:
            tvCount++;
            scannedShows[libraryEntry.media.id] = libraryEntry.media;
            break;
          case MediaType.unknown:
            break;
        }
      }
    }

    await walk(root);
    for (final show in scannedShows.values) {
      await _repo.consolidateTvShow(show);
    }

    return SmbLibraryImportResult(
      scannedFiles: scannedFiles,
      importedItems: importedItems,
      movieCount: movieCount,
      tvCount: tvCount,
      episodeCount: episodeCount,
      rootPath: root.path,
      mediaIds: mediaIds,
    );
  }
}
