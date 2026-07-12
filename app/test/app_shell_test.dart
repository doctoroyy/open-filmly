import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/core/router/app_router.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/providers/data_providers.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mediaRepo = MediaRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/',
    Size size = const Size(1600, 1200),
  }) async {
    tester.view.physicalSize = size;
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
  }

  testWidgets('shell shows the macOS-style sidebar with library nav', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Open Filmly'), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/recent')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/movies')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/tv')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/anime')), findsOneWidget);
    // Bottom quick actions (favorites / sources / settings).
    expect(find.byKey(const Key('sidebar_/favorites')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/sources')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/config')), findsOneWidget);
    expect(find.text('最近观看'), findsOneWidget);
    expect(find.text('动漫'), findsOneWidget);
  });

  testWidgets('home top bar exposes search / refresh / add actions', (
    tester,
  ) async {
    await pumpApp(tester);
    // Sidebar search pill + home top-bar search.
    expect(find.byIcon(Icons.search_rounded), findsAtLeastNWidgets(2));
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    // add_rounded is in the top bar (and the empty-state button).
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });

  testWidgets('sidebar settings item navigates to the config page', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('sidebar_/config')));
    await tester.pumpAndSettle();

    expect(find.textContaining('SMB'), findsAtLeastNWidgets(1));
  });

  testWidgets('sidebar sources item opens the sources page', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('sidebar_/sources')));
    await tester.pumpAndSettle();

    expect(find.text('来源管理'), findsOneWidget);
  });

  testWidgets('sidebar persists across navigation', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('sidebar_/movies')));
    await tester.pumpAndSettle();

    // Sidebar still present after navigating into a section.
    expect(find.byKey(const Key('sidebar_/')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/tv')), findsOneWidget);
  });

  testWidgets('compact layouts use mobile bottom navigation', (tester) async {
    await pumpApp(tester, size: const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/')), findsNothing);
    expect(find.text('更多'), findsOneWidget);
  });

  testWidgets('movie details keep the movie sidebar selected', (tester) async {
    await mediaRepo.upsert(
      const Media(
        id: 'movie-1',
        title: 'Movie',
        year: '2026',
        type: MediaType.movie,
        path: '/movie.mkv',
      ),
    );

    await pumpApp(tester, initialLocation: mediaDetailLocation('movie-1'));
    await tester.pumpAndSettle();

    final semantics = tester.widgetList<Semantics>(
      find.descendant(
        of: find.byKey(const Key('sidebar_/movies')),
        matching: find.byType(Semantics),
      ),
    );
    expect(
      semantics.any((widget) => widget.properties.selected == true),
      isTrue,
    );
  });
}
