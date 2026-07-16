import 'package:drift/native.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/core/router/app_router.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/models/library_shelf.dart';
import 'package:open_filmly/data/models/playback_progress.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/data/repositories/playback_progress_repository.dart';
import 'package:open_filmly/features/library/library_page.dart';
import 'package:open_filmly/providers/data_providers.dart';
import 'package:open_filmly/widgets/media_poster_card.dart';

class _LibraryInvalidationHarness extends ConsumerWidget {
  const _LibraryInvalidationHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: Column(
        children: [
          TextButton(
            key: const Key('invalidate_library_views'),
            onPressed: () => invalidateLibraryViews(ref),
            child: const Text('刷新媒体库'),
          ),
          const Expanded(child: LibraryPage(shelf: LibraryShelf.movie)),
        ],
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late MediaRepository repo;
  late PlaybackProgressRepository progressRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
    progressRepo = PlaybackProgressRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/',
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = createAppRouter(initialLocation: initialLocation);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('dashboard shows top bar and library shelves', (tester) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: 'The Matrix',
        year: '1999',
        type: MediaType.movie,
        path: '/movies/matrix.mkv',
        dateAdded: '2026-06-01T10:00:00.000',
      ),
    );
    await repo.upsert(
      const Media(
        id: 'tv-1',
        title: 'Breaking Bad',
        year: '2008',
        type: MediaType.tv,
        path: '/tv/breaking-bad',
        dateAdded: '2026-06-01T11:00:00.000',
      ),
    );

    await pumpApp(tester);

    expect(find.text('Open Filmly'), findsOneWidget);
    // '电影' / '电视剧' appear both as sidebar items and shelf titles.
    expect(find.text('电影'), findsWidgets);
    expect(find.text('电视剧'), findsWidgets);
    expect(find.byType(MediaPosterCard), findsAtLeastNWidgets(1));
  });

  testWidgets('top bar search button opens the global search overlay', (
    tester,
  ) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: 'The Matrix',
        year: '1999',
        type: MediaType.movie,
        path: '/movies/matrix.mkv',
        detailsJson: '{"overview":"Neo enters the matrix"}',
      ),
    );

    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('global_search_field')), 'neo');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.descendant(
        of: find.byKey(const Key('global_search_overlay')),
        matching: find.text('The Matrix'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dashboard shows the 最近播放 shelf for in-progress media', (
    tester,
  ) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: 'The Matrix',
        year: '1999',
        type: MediaType.movie,
        path: '/movies/matrix.mkv',
        posterPath: 'https://image.tmdb.org/t/p/w500/poster.jpg',
        detailsJson: '{"backdrop_path":"/backdrop.jpg"}',
        dateAdded: '2026-06-01T10:00:00.000',
      ),
    );
    await progressRepo.save(
      PlaybackProgress(
        mediaId: 'movie-1',
        position: const Duration(minutes: 12),
        duration: const Duration(minutes: 45),
        updatedAt: DateTime.parse('2026-06-01T12:00:00.000Z'),
      ),
    );

    await pumpApp(tester);

    // Sidebar uses 「最近观看」; the in-progress shelf title stays 「最近播放」.
    expect(find.text('最近观看'), findsOneWidget);
    expect(find.text('最近播放'), findsOneWidget);
    final landscape = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(landscape.imageUrl, 'https://image.tmdb.org/t/p/w780/backdrop.jpg');
  });

  testWidgets('library route opens media detail page', (tester) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: 'The Matrix',
        year: '1999',
        type: MediaType.movie,
        path: '/movies/matrix.mkv',
        detailsJson:
            '{"overview":"Neo learns the truth.","genres":["Sci-Fi","Action"]}',
        dateAdded: '2026-06-01T10:00:00.000',
      ),
    );

    await pumpApp(tester, initialLocation: '/movies');

    expect(find.byType(MediaPosterCard), findsOneWidget);

    await tester.tap(find.byType(MediaPosterCard));
    await tester.pumpAndSettle();

    // Detail hero shows title, overview, a play action, and source info.
    expect(find.text('Neo learns the truth.'), findsOneWidget);
    expect(find.text('片源路径'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
  });

  testWidgets('library page filters media by search term', (tester) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: 'The Matrix',
        year: '1999',
        type: MediaType.movie,
        path: '/movies/matrix.mkv',
      ),
    );
    await repo.upsert(
      const Media(
        id: 'movie-2',
        title: 'Inception',
        year: '2010',
        type: MediaType.movie,
        path: '/movies/inception.mkv',
      ),
    );

    await pumpApp(tester, initialLocation: '/movies');

    expect(find.byType(MediaPosterCard), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 'matrix');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MediaPosterCard), findsOneWidget);
  });

  testWidgets('metadata refresh updates an already-mounted library page', (
    tester,
  ) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: '旧标题',
        year: '2026',
        type: MediaType.movie,
        path: '/movies/movie-1.mkv',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const _LibraryInvalidationHarness(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧标题'), findsWidgets);

    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: '校正后的标题',
        year: '2026',
        type: MediaType.movie,
        path: '/movies/movie-1.mkv',
      ),
    );
    await tester.tap(find.byKey(const Key('invalidate_library_views')));
    await tester.pumpAndSettle();

    expect(find.text('校正后的标题'), findsWidgets);
    expect(find.text('旧标题'), findsNothing);
  });

  testWidgets('detail page shows resume action when progress exists', (
    tester,
  ) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: 'The Matrix',
        year: '1999',
        type: MediaType.movie,
        path: '/movies/matrix.mkv',
        fullPath: '/movies/matrix.mkv',
      ),
    );
    await progressRepo.save(
      PlaybackProgress(
        mediaId: 'movie-1',
        position: const Duration(minutes: 30),
        duration: const Duration(hours: 2),
        updatedAt: DateTime.now(),
      ),
    );

    await pumpApp(tester, initialLocation: mediaDetailLocation('movie-1'));
    await tester.pumpAndSettle();

    expect(find.text('继续播放'), findsOneWidget);
    expect(find.text('从头播放'), findsOneWidget);
  });

  testWidgets('detail opens for ids containing slashes, spaces and CJK', (
    tester,
  ) async {
    // Real-world media id: a raw file path. A path-segment route would 404
    // (GoException: no routes for location) — it must travel as a query param.
    const rawId =
        '/Volumes/wd-downloads/IMDB TOP 250/249.误杀 Drishyam.2015.1080p.mkv';
    await repo.upsert(
      const Media(
        id: rawId,
        title: 'Drishyam',
        year: '2015',
        type: MediaType.movie,
        path: rawId,
        fullPath: rawId,
      ),
    );

    await pumpApp(tester, initialLocation: mediaDetailLocation(rawId));
    await tester.pumpAndSettle();

    expect(find.text('Page Not Found'), findsNothing);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('片源路径'), findsOneWidget);
  });

  testWidgets('config page exposes library scan controls', (tester) async {
    await pumpApp(tester, initialLocation: '/config');

    expect(find.textContaining('SMB'), findsAtLeastNWidgets(1));
  });
}
