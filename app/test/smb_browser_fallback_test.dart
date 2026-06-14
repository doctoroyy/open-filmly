import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/features/config/smb_browser_page.dart';
import 'package:open_filmly/providers/data_providers.dart';
import 'package:open_filmly/providers/smb_providers.dart';
import 'package:open_filmly/services/smb/smb_service.dart';

import 'test_support/fake_smb_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> connect(WidgetTester tester, FakeSmbService smb) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          smbServiceProvider.overrideWithValue(smb),
        ],
        child: const MaterialApp(home: SmbBrowserPage()),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'nas');
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();
  }

  testWidgets('auto-discovers common shares when enumeration is unsupported', (
    tester,
  ) async {
    final smb = FakeSmbService(
      initialConfig: const SmbConfig(host: 'nas'),
      connected: false,
      failShares: true, // server without srvsvc enumeration
      directories: {
        '/Media': [smbFile('/Media/Dune.2021.mkv', size: 10)],
      },
    );

    await connect(tester, smb);

    // "Media" was discovered by probing common names — shown as a folder tile.
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('未自动发现共享'), findsNothing);

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    expect(find.text('Dune.2021.mkv'), findsOneWidget);
  });

  testWidgets('falls back to manual entry only when discovery finds nothing', (
    tester,
  ) async {
    final smb = FakeSmbService(
      initialConfig: const SmbConfig(host: 'nas'),
      connected: false,
      failShares: true,
      directories: {
        // A custom share name not in the common list.
        '/MyCustomVault': [smbFile('/MyCustomVault/x.mkv', size: 10)],
      },
    );

    await connect(tester, smb);

    // Nothing common matched → the manual-entry prompt appears.
    expect(find.text('未自动发现共享'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'MyCustomVault');
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('x.mkv'), findsOneWidget);
  });
}
