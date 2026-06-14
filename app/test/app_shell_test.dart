import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/core/router/app_router.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/providers/data_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
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
    expect(find.byKey(const Key('sidebar_/variety')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/concert')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/documentary')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/other')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/sources')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_/config')), findsOneWidget);
  });

  testWidgets('home top bar exposes search / refresh / add actions', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('home_search_button')), findsOneWidget);
    expect(find.byKey(const Key('home_refresh_button')), findsOneWidget);
    expect(find.byKey(const Key('home_add_source_button')), findsOneWidget);
  });

  testWidgets('sidebar settings item navigates to the config page', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('sidebar_/config')));
    await tester.pumpAndSettle();

    expect(find.textContaining('SMB'), findsAtLeastNWidgets(1));
  });

  testWidgets('home add source action opens the sources page', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('home_add_source_button')));
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
}
