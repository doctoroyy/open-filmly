import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:http/http.dart' as http;

import '../data/database/database.dart';
import '../data/models/app_config.dart';
import '../data/models/continue_watching_item.dart';
import '../data/models/episode.dart';
import '../data/models/media.dart';
import '../data/models/media_library_query.dart';
import '../data/models/playback_progress.dart';
import '../data/repositories/config_repository.dart';
import '../data/repositories/episode_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/playback_progress_repository.dart';
import '../services/library/library_auto_scan_service.dart';
import '../services/library/library_metadata_sync_service.dart';
import '../services/library/library_scanner_service.dart';
import '../services/metadata/intelligent_name_recognizer.dart';
import '../services/metadata/tmdb_metadata_service.dart';

/// App-lifetime drift database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(databaseProvider)),
);

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepository(ref.watch(databaseProvider)),
);

final playbackProgressRepositoryProvider = Provider<PlaybackProgressRepository>(
  (ref) => PlaybackProgressRepository(ref.watch(databaseProvider)),
);

final episodeRepositoryProvider = Provider<EpisodeRepository>(
  (ref) => EpisodeRepository(ref.watch(databaseProvider)),
);

final libraryScannerProvider = Provider<LibraryScannerService>(
  (ref) => LibraryScannerService(
    ref.watch(mediaRepositoryProvider),
    ref.watch(episodeRepositoryProvider),
  ),
);

final tmdbHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tmdbMetadataProvider = Provider<TmdbMetadataService>((ref) {
  return TmdbMetadataService(ref.watch(tmdbHttpClientProvider));
});

final intelligentNameRecognizerProvider = Provider<IntelligentNameRecognizer>((
  ref,
) {
  return IntelligentNameRecognizer(ref.watch(tmdbHttpClientProvider));
});

final libraryMetadataSyncProvider = Provider<LibraryMetadataSyncService>((ref) {
  return LibraryMetadataSyncService(
    ref.watch(mediaRepositoryProvider),
    ref.watch(tmdbMetadataProvider),
    ref.watch(intelligentNameRecognizerProvider),
    ref.watch(episodeRepositoryProvider),
  );
});

final libraryAutoScanProvider = Provider<LibraryAutoScanService>((ref) {
  return LibraryAutoScanService(
    ref.watch(libraryScannerProvider),
    ref.watch(libraryMetadataSyncProvider),
    ref.watch(mediaRepositoryProvider),
  );
});

/// Current application config, loaded from the database and saved on change.
final configProvider = AsyncNotifierProvider<ConfigNotifier, AppConfig>(
  ConfigNotifier.new,
);

class ConfigNotifier extends AsyncNotifier<AppConfig> {
  @override
  Future<AppConfig> build() => ref.watch(configRepositoryProvider).load();

  Future<void> save(AppConfig config) async {
    state = AsyncData(config);
    await ref.read(configRepositoryProvider).save(config);
  }
}

/// Library items of a given type, sorted by title.
final mediaLibraryProvider = FutureProvider.family<List<Media>, MediaType>((
  ref,
  type,
) {
  return ref.watch(mediaRepositoryProvider).getByType(type);
});

/// Browse a library section with search + sorting applied.
final mediaBrowseProvider =
    FutureProvider.family<List<Media>, MediaLibraryQuery>((ref, query) {
      return ref
          .watch(mediaRepositoryProvider)
          .browse(
            type: query.type,
            searchTerm: query.searchTerm,
            sort: query.sort,
            genreTerms: query.genreTerms,
          );
    });

/// Item counts grouped by media type for the dashboard summary.
final libraryCountsProvider = FutureProvider<Map<MediaType, int>>((ref) {
  return ref.watch(mediaRepositoryProvider).countByType();
});

/// Recently added items for the dashboard surfaces.
final recentMediaProvider = FutureProvider<List<Media>>((ref) {
  return ref.watch(mediaRepositoryProvider).getRecentlyAdded();
});

/// Favorited items, for the favorites shelf/route.
final favoritesProvider = FutureProvider<List<Media>>((ref) {
  return ref.watch(mediaRepositoryProvider).getFavorites();
});

/// Top-rated items for featured shelves and sidebar highlights.
final topRatedMediaProvider = FutureProvider<List<Media>>((ref) {
  return ref
      .watch(mediaRepositoryProvider)
      .browse(sort: MediaSort.rating, limit: 8);
});

/// Featured movies for the home overview.
final featuredMoviesProvider = FutureProvider<List<Media>>((ref) {
  return ref
      .watch(mediaRepositoryProvider)
      .browse(type: MediaType.movie, sort: MediaSort.recentlyAdded, limit: 8);
});

/// Featured TV shows for the home overview.
final featuredTvProvider = FutureProvider<List<Media>>((ref) {
  return ref
      .watch(mediaRepositoryProvider)
      .browse(type: MediaType.tv, sort: MediaSort.recentlyAdded, limit: 8);
});

/// Global dashboard search across the whole library.
final mediaSearchProvider = FutureProvider.family<List<Media>, String>((
  ref,
  query,
) {
  return ref.watch(mediaRepositoryProvider).search(query);
});

/// Single media item by id for the detail route.
final mediaByIdProvider = FutureProvider.family<Media?, String>((ref, id) {
  return ref.watch(mediaRepositoryProvider).getById(id);
});

/// Latest playback resume point for a single item.
final playbackProgressByMediaIdProvider =
    FutureProvider.family<PlaybackProgress?, String>((ref, id) {
      return ref.watch(playbackProgressRepositoryProvider).getByMediaId(id);
    });

/// Home dashboard shelf for items that should resume where the user left off.
final continueWatchingProvider = FutureProvider<List<ContinueWatchingItem>>((
  ref,
) async {
  final progressItems = await ref
      .watch(playbackProgressRepositoryProvider)
      .getContinueWatching();
  if (progressItems.isEmpty) return const [];

  final repo = ref.watch(mediaRepositoryProvider);
  final mediaItems = await Future.wait(
    progressItems.map((progress) => repo.getById(progress.mediaId)),
  );

  final entries = <ContinueWatchingItem>[];
  for (var i = 0; i < progressItems.length; i++) {
    final media = mediaItems[i];
    if (media == null) continue;
    entries.add(ContinueWatchingItem(media: media, progress: progressItems[i]));
  }
  return entries;
});

/// Media items that were recently watched or resumed.
final recentlyWatchedMediaProvider = FutureProvider<List<Media>>((ref) async {
  final items = await ref.watch(continueWatchingProvider.future);
  return items.map((item) => item.media).toList(growable: false);
});

/// Episodes for a TV show, grouped by season.
final episodesByShowProvider = FutureProvider.family<List<Season>, String>((
  ref,
  showId,
) {
  return ref.watch(episodeRepositoryProvider).getByShowGrouped(showId);
});

/// Episode count for a show (used in list views).
final episodeCountProvider = FutureProvider.family<int, String>((ref, showId) {
  return ref.watch(episodeRepositoryProvider).countByShow(showId);
});

/// Identifies one episode of one show for the episode-details lookup.
typedef EpisodeRef = ({String showId, int season, int episode});

/// On-demand TMDB metadata for a single episode (still, overview, air date).
/// Returns null when the show lacks a TMDB id or no API key is configured.
final episodeDetailsProvider =
    FutureProvider.family<TmdbEpisodeDetails?, EpisodeRef>((ref, key) async {
      final show = await ref.watch(mediaByIdProvider(key.showId).future);
      final tmdbId = show?.tmdbId;
      if (tmdbId == null) return null;

      final config = await ref.watch(configProvider.future);
      if (config.tmdbApiKey.isEmpty) return null;

      return ref
          .watch(tmdbMetadataProvider)
          .fetchEpisodeDetails(
            tvId: tmdbId,
            seasonNumber: key.season,
            episodeNumber: key.episode,
            apiKey: config.tmdbApiKey,
          );
    });

/// Top-billed cast for the detail page's 相关演员 row. Empty when the item
/// lacks a TMDB id or no API key is configured.
final castProvider = FutureProvider.family<List<TmdbCastMember>, String>((
  ref,
  mediaId,
) async {
  final media = await ref.watch(mediaByIdProvider(mediaId).future);
  final tmdbId = media?.tmdbId;
  if (media == null || tmdbId == null) return const [];

  final config = await ref.watch(configProvider.future);
  if (config.tmdbApiKey.isEmpty) return const [];

  return ref
      .watch(tmdbMetadataProvider)
      .fetchCredits(
        tmdbId: tmdbId,
        type: media.type,
        apiKey: config.tmdbApiKey,
      );
});

/// Invalidates every library-facing provider after a scan or metadata refresh,
/// so all dashboard shelves, library grids, and sidebar counts rebuild.
void invalidateLibraryViews(WidgetRef ref) {
  ref.invalidate(libraryCountsProvider);
  ref.invalidate(recentMediaProvider);
  ref.invalidate(topRatedMediaProvider);
  ref.invalidate(featuredMoviesProvider);
  ref.invalidate(featuredTvProvider);
  ref.invalidate(continueWatchingProvider);
  ref.invalidate(recentlyWatchedMediaProvider);
  ref.invalidate(favoritesProvider);
  ref.invalidate(mediaLibraryProvider);
}
