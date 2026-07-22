import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/features/intelligence/media_agent_page.dart';
import 'package:open_filmly/providers/data_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('presents the empty Agent state as a workbench', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: MediaAgentPage()),
      ),
    );

    expect(find.byKey(const Key('agent_workbench_welcome')), findsOneWidget);
    expect(find.text('Your library,\nwith intent.'), findsOneWidget);
    expect(find.byKey(const Key('agent_request_input')), findsOneWidget);
  });
}
