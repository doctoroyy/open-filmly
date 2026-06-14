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
  late MediaRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = createAppRouter(initialLocation: '/');
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

  testWidgets('sidebar search entry opens global search overlay', (
    tester,
  ) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: 'Interstellar',
        year: '2014',
        type: MediaType.movie,
        path: '/movies/interstellar.mkv',
      ),
    );

    await pumpApp(tester);

    // The top bar shows a search action.
    expect(find.byKey(const Key('home_search_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_search_button')));
    await tester.pumpAndSettle();

    // The overlay's search field placeholder is now visible.
    expect(find.text('搜索全部影片、剧集…'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('global_search_field')),
      'inter',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // The matching item appears in the overlay results.
    expect(
      find.descendant(
        of: find.byKey(const Key('global_search_overlay')),
        matching: find.text('Interstellar'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('global search filters out non-matching items', (tester) async {
    await repo.upsert(
      const Media(
        id: 'movie-1',
        title: 'Interstellar',
        year: '2014',
        type: MediaType.movie,
        path: '/movies/interstellar.mkv',
      ),
    );
    await repo.upsert(
      const Media(
        id: 'movie-2',
        title: 'The Godfather',
        year: '1972',
        type: MediaType.movie,
        path: '/movies/godfather.mkv',
      ),
    );

    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home_search_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('global_search_field')),
      'godfather',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final overlay = find.byKey(const Key('global_search_overlay'));
    expect(
      find.descendant(of: overlay, matching: find.text('The Godfather')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('Interstellar')),
      findsNothing,
    );
  });
}
