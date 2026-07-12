import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/features/config/smb_browser_page.dart';
import 'package:open_filmly/providers/data_providers.dart';
import 'package:open_filmly/providers/smb_providers.dart';
import 'package:open_filmly/services/smb/smb_proxy_server.dart';
import 'package:open_filmly/services/smb/smb_service.dart';
import 'package:smb_connect/smb_connect.dart';

import 'test_support/fake_smb_service.dart';

class FakeSmbProxyServer extends SmbProxyServer {
  FakeSmbProxyServer(super.smb);
  @override
  Future<void> start({int port = 0}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('SmbBrowserPage deep directory browsing and attribute fallback', (
    tester,
  ) async {
    // Create a fake folder structure:
    // /Movies
    //   /Movies/Action          (standard directory)
    //   /Movies/Downloads       (missing DIRECTORY attribute, but not a video)
    //   /Movies/Downloads/Test.mp4

    final actionDir = smbDir('/Movies/Action');

    // Create a directory that lacks the DIRECTORY attribute (0x10).
    // Use 0x20 (ARCHIVE) like a normal file, but give it no extension to
    // simulate Samba quirks.
    final downloadsDir = SmbFile(
      '/Movies/Downloads',
      '\\\\nas\\Movies\\Downloads',
      'Movies',
      0,
      0,
      0,
      0x20, // Not a directory!
      0, // Size 0
      true,
    );

    final smb = FakeSmbService(
      initialConfig: const SmbConfig(host: '192.168.31.252'),
      connected: false,
      directories: {
        '__shares__': [smbShare('Movies')],
        '/Movies': [actionDir, downloadsDir],
        '/Movies/Downloads': [smbFile('/Movies/Downloads/Test.mp4')],
      },
    );

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          smbServiceProvider.overrideWithValue(smb),
          // Stub proxy so we don't try to bind a real socket
          smbProxyProvider.overrideWithValue(FakeSmbProxyServer(smb)),
        ],
        child: const MaterialApp(home: SmbBrowserPage()),
      ),
    );

    await tester.pumpAndSettle();

    // Fill in connection form and connect
    await tester.enterText(find.byType(TextField).first, '192.168.31.252');
    await tester.ensureVisible(find.text('连接'));
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    // 1. We should see the share list
    expect(find.text('Movies'), findsOneWidget);
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();

    // 2. We should see Action and Downloads
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);

    // 3. Tap "Downloads". Even though it doesn't have the DIRECTORY attribute,
    // it's not a video, so it should be treated as a tappable directory.
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    // 4. We should be inside Downloads and see Test.mp4
    expect(find.text('Test.mp4'), findsOneWidget);

    // 5. Navigate back
    await tester.tap(find.text('上级目录'));
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsOneWidget); // Back to Movies
  });
}
