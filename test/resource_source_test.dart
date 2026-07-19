import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filmly/core/router/app_router.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/app_config.dart';
import 'package:open_filmly/data/models/resource_source.dart';
import 'package:open_filmly/providers/data_providers.dart';

void main() {
  test('resource sources round-trip including SMB domain and imports', () {
    const source = ResourceSource(
      id: 'nas-1',
      name: '树莓派',
      type: ResourceSourceType.smb,
      endpoint: '192.168.1.10',
      port: '445',
      username: 'media',
      password: 'secret',
      domain: 'WORKGROUP',
      path: 'downloads',
      importedPaths: ['/downloads/tv'],
    );

    final restored = AppConfig.fromJson(
      AppConfig(resourceSources: const [source]).toJson(),
    );

    expect(restored.resourceSources, hasLength(1));
    expect(restored.resourceSources.single.domain, 'WORKGROUP');
    expect(restored.resourceSources.single.importedPaths, ['/downloads/tv']);
  });

  test('legacy singleton network settings migrate to source cards', () {
    final config = AppConfig.fromJson({
      'smbHost': 'nas.local',
      'smbUsername': 'guest',
      'smbDomain': 'WORKGROUP',
      'smbShare': 'media',
      'webdavUrl': 'https://dav.local/dav',
      'webdavUsername': 'xiaoyu',
    });

    expect(
      config.resourceSources.map((source) => source.type),
      containsAll(<ResourceSourceType>[
        ResourceSourceType.smb,
        ResourceSourceType.webdav,
      ]),
    );
    expect(
      config.resourceSources
          .firstWhere((source) => source.type == ResourceSourceType.smb)
          .domain,
      'WORKGROUP',
    );
  });

  testWidgets('resource library offers a guided SMB entry when empty', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final router = createAppRouter(initialLocation: '/sources');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('资源库'), findsOneWidget);
    expect(find.byKey(const Key('source_card_smb')), findsOneWidget);
  });
}
