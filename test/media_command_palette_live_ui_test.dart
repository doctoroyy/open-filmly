import 'dart:convert';
import 'dart:io';

import 'package:flutter_skill/src/drivers/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real macOS smoke test. It connects to a running Debug build and searches
/// the user's existing library; no provider or network response is mocked.
void main() {
  final vmUri = Platform.environment['FLUTTER_SKILL_URI']?.trim() ?? '';
  final enabled = vmUri.startsWith('ws://');
  test(
    'opens a real library result from the Agent command palette',
    () async {
      final client = FlutterSkillClient(vmUri);
      addTearDown(client.disconnect);
      await client.connect();

      await _dismissOpenPalette(client);
      await client.tap(key: 'sidebar_/agent');
      await _waitFor(client, 'agent_open_command_palette');
      await _saveScreenshot(client, '00-agent-workbench');
      await client.tap(key: 'agent_open_command_palette');
      await _waitFor(client, 'media_command_palette_field');
      await _saveScreenshot(client, '01-command-palette');

      await client.tap(key: 'media_command_palette_field');
      await client.enterText('media_command_palette_field', '唐朝诡事录');
      expect(await client.getTextValue('media_command_palette_field'), '唐朝诡事录');
      await _waitFor(client, 'media_command_result_0');
      final texts = await client.getTextContent();
      expect(
        texts
            .whereType<Map>()
            .map((value) => value['text']?.toString() ?? '')
            .join('\n'),
        contains('唐朝诡事录'),
      );
      await _saveScreenshot(client, '02-real-library-results');

      await _waitFor(client, 'media_command_result_0_selected');
      await client.tap(key: 'media_command_result_0');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _saveScreenshot(client, '03-after-result-open');
      await _waitUntilAbsent(client, 'media_command_palette_field');
      await _waitForText(client, '唐朝诡事录');
      await _saveScreenshot(client, '04-opened-result');

      // Leave the debug app on the workbench so a clean desktop capture can
      // inspect the final UI without FlutterSkill's interaction indicator.
      await client.tap(key: 'sidebar_/agent');
      await _waitFor(client, 'agent_request_input');
    },
    timeout: const Timeout(Duration(seconds: 45)),
    skip: enabled
        ? false
        : 'Set FLUTTER_SKILL_URI for a running macOS Debug app to run live UI tests.',
  );
}

Future<void> _dismissOpenPalette(FlutterSkillClient client) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    if (await client.getWidgetProperties('media_command_palette_field') ==
        null) {
      return;
    }
    await client.pressKey('escape');
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

Future<void> _waitFor(FlutterSkillClient client, String key) async {
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  while (DateTime.now().isBefore(deadline)) {
    if (await client.getWidgetProperties(key) != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError('Timed out waiting for $key');
}

Future<void> _waitUntilAbsent(FlutterSkillClient client, String key) async {
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  while (DateTime.now().isBefore(deadline)) {
    if (await client.getWidgetProperties(key) == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError('Timed out waiting for $key to disappear');
}

Future<void> _waitForText(FlutterSkillClient client, String expected) async {
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  while (DateTime.now().isBefore(deadline)) {
    final text = (await client.getTextContent())
        .whereType<Map>()
        .map((value) => value['text']?.toString() ?? '')
        .join('\n');
    if (text.contains(expected)) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError('Timed out waiting for $expected');
}

Future<void> _saveScreenshot(FlutterSkillClient client, String name) async {
  final image = await client.takeScreenshot();
  if (image == null) throw StateError('Unable to capture $name');
  final output = Directory('/tmp/open-filmly-command-palette-live');
  await output.create(recursive: true);
  await File('${output.path}/$name.png').writeAsBytes(base64Decode(image));
}
