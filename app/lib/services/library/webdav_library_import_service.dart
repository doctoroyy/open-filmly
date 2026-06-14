import '../../data/models/media.dart';
import '../../data/repositories/episode_repository.dart';
import '../../data/repositories/media_repository.dart';
import '../webdav/webdav_service.dart';
import 'media_library_entry_factory.dart';

/// Summary returned after importing a WebDAV folder into the media library.
class WebDavLibraryImportResult {
  const WebDavLibraryImportResult({
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

/// Recursively imports WebDAV video files from the active session into the
/// library. Mirrors [SmbLibraryImportService] but over plain HTTP(S).
class WebDavLibraryImportService {
  WebDavLibraryImportService(this._dav, this._repo, [this._episodeRepo]);

  final WebDavService _dav;
  final MediaRepository _repo;
  final EpisodeRepository? _episodeRepo;

  Future<WebDavLibraryImportResult> importFolder(String rootPath) async {
    final config = _dav.config;
    if (!_dav.isConnected || config == null) {
      throw StateError('WebDAV connection not established');
    }
    final baseUrl = config.url;

    var scannedFiles = 0;
    var importedItems = 0;
    var movieCount = 0;
    var tvCount = 0;
    var episodeCount = 0;
    final mediaIds = <String>[];
    final visited = <String>{};

    Future<void> walk(String dirPath) async {
      if (!visited.add(dirPath)) return;

      final entries = await _dav.listDir(dirPath);
      for (final entry in entries) {
        if (entry.isDir) {
          await walk(entry.path);
          continue;
        }
        if (!MediaLibraryEntryFactory.isImportableVideo(entry.path)) continue;

        scannedFiles++;
        final libraryEntry = MediaLibraryEntryFactory.fromWebDavFile(
          baseUrl: baseUrl,
          relativePath: entry.path,
        );
        await _repo.upsert(libraryEntry.media);
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
            break;
          case MediaType.unknown:
            break;
        }
      }
    }

    await walk(rootPath);

    return WebDavLibraryImportResult(
      scannedFiles: scannedFiles,
      importedItems: importedItems,
      movieCount: movieCount,
      tvCount: tvCount,
      episodeCount: episodeCount,
      rootPath: rootPath,
      mediaIds: mediaIds,
    );
  }
}
