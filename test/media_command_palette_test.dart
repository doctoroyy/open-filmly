import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/providers/data_providers.dart';
import 'package:open_filmly/providers/intelligence_providers.dart';
import 'package:open_filmly/services/intelligence/semantic_search_service.dart';
import 'package:open_filmly/widgets/media_command_palette.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpPalette(
    WidgetTester tester, {
    List<dynamic> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database), ...overrides],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => MediaCommandPalette.show(context),
                  child: const Text('Open palette'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open palette'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens a Spotlight-style command palette with library actions', (
    tester,
  ) async {
    await pumpPalette(tester);

    expect(find.byKey(const Key('media_command_palette')), findsOneWidget);
    expect(
      find.byKey(const Key('media_command_palette_field')),
      findsOneWidget,
    );
    expect(find.text('SEARCH YOUR LIBRARY'), findsOneWidget);
    expect(find.text('Continue in Filmly'), findsOneWidget);
    expect(
      find.byKey(const Key('media_command_palette_continue_conversation')),
      findsOneWidget,
    );
  });

  testWidgets('shows semantic matches in a directly actionable result list', (
    tester,
  ) async {
    const result = AskFilmlyResult(
      title: 'Rain Film',
      year: '2026',
      mediaId: 'rain-film',
      uri: '/Movies/rain-film.mkv',
      startMs: 61000,
      endMs: 68000,
      snippet: 'A meeting waits in the rain.',
      reason: 'Scene match',
      score: 9,
    );
    await pumpPalette(
      tester,
      overrides: [
        askFilmlyProvider.overrideWith(
          (ref, query) async => query == 'rain' ? [result] : const [],
        ),
      ],
    );

    await tester.enterText(
      find.byKey(const Key('media_command_palette_field')),
      'rain',
    );
    await tester.pumpAndSettle();

    expect(find.text('RESULTS FROM YOUR LIBRARY'), findsOneWidget);
    expect(find.text('Rain Film'), findsOneWidget);
    expect(find.text('01:01'), findsOneWidget);
    expect(find.text('Scene match'), findsOneWidget);
    expect(find.byKey(const Key('media_command_result_0')), findsOneWidget);
  });

  testWidgets('dismisses the palette before opening a selected result', (
    tester,
  ) async {
    const result = AskFilmlyResult(
      title: 'Unresolved library item',
      snippet: 'A result without a navigable location.',
      reason: 'Metadata match',
      score: 1,
    );
    await pumpPalette(
      tester,
      overrides: [
        askFilmlyProvider.overrideWith(
          (ref, query) async => query == 'unresolved' ? [result] : const [],
        ),
      ],
    );

    await tester.enterText(
      find.byKey(const Key('media_command_palette_field')),
      'unresolved',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media_command_result_0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media_command_palette')), findsNothing);
  });

  testWidgets('uses Arrow keys to choose the result opened by Enter', (
    tester,
  ) async {
    const first = AskFilmlyResult(
      title: 'First match',
      snippet: 'First',
      reason: 'Metadata match',
      score: 2,
    );
    const second = AskFilmlyResult(
      title: 'Second match',
      snippet: 'Second',
      reason: 'Metadata match',
      score: 1,
    );
    await pumpPalette(
      tester,
      overrides: [
        askFilmlyProvider.overrideWith(
          (ref, query) async =>
              query == 'matches' ? const [first, second] : const [],
        ),
      ],
    );

    await tester.enterText(
      find.byKey(const Key('media_command_palette_field')),
      'matches',
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(
      find.byKey(const Key('media_command_result_1_selected')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media_command_palette')), findsNothing);
  });

  testWidgets('Ctrl+K closes an open command palette', (tester) async {
    await pumpPalette(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media_command_palette')), findsNothing);
  });
}
