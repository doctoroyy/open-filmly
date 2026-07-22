import 'dart:convert';
import 'dart:io';

import 'package:flutter_skill/src/drivers/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses the configured Gemini key to plan and execute a safe Agent task',
    () async {
      final uriFile = File('.flutter_skill_uri');
      expect(
        await uriFile.exists(),
        isTrue,
        reason: 'Start the macOS debug app before running this live UI test.',
      );
      final uri = (await uriFile.readAsString()).trim();
      expect(uri, startsWith('ws://'));
      final client = FlutterSkillClient(uri);
      addTearDown(client.disconnect);
      await client.connect();

      // ignore: avoid_print
      print('Opening Media Agent…');
      await client.tap(key: 'sidebar_/agent');
      await _waitFor(client, 'agent_request_input');
      await _saveScreenshot(client, '01-agent-ready');

      // ignore: avoid_print
      print('Requesting a live Gemini plan…');
      await client.enterText('agent_request_input', '把没看过的科幻片建个合集');
      await client.tap(key: 'agent_gemini_plan_button');
      final completedKey = await _waitForAny(client, const [
        'agent_plan_panel',
        'agent_error_text',
      ], timeout: const Duration(seconds: 60));
      if (completedKey == 'agent_error_text') {
        await _saveScreenshot(client, '02-gemini-error');
        final text = await _textForKey(client, 'agent_error_text');
        throw StateError('Gemini Agent planning failed in the real app: $text');
      }
      await _saveScreenshot(client, '02-gemini-plan');

      await client.tap(key: 'agent_confirm_plan_button');
      await _waitFor(client, 'agent_execute_plan_button');
      await client.tap(key: 'agent_execute_plan_button');
      await _waitForStatus(client, '已完成');
      await _saveScreenshot(client, '03-agent-complete');
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

Future<void> _waitFor(
  FlutterSkillClient client,
  String key, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await client.getWidgetProperties(key) != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('Timed out waiting for $key');
}

Future<void> _waitForStatus(FlutterSkillClient client, String status) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    final values = await client.getTextContent();
    final text = values
        .whereType<Map>()
        .map((value) => value['text']?.toString() ?? '')
        .join('\n');
    if (text.contains(status)) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('Timed out waiting for status: $status');
}

Future<String> _waitForAny(
  FlutterSkillClient client,
  List<String> keys, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    for (final key in keys) {
      if (await client.getWidgetProperties(key) != null) return key;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('Timed out waiting for one of: ${keys.join(', ')}');
}

Future<String> _textForKey(FlutterSkillClient client, String key) async {
  final values = await client.getTextContent();
  for (final value in values.whereType<Map>()) {
    if (value['key'] == key) return value['text']?.toString() ?? '';
  }
  return '';
}

Future<void> _saveScreenshot(FlutterSkillClient client, String name) async {
  final value = await client.takeScreenshot();
  if (value == null) throw StateError('Could not capture screenshot: $name');
  final directory = Directory('/tmp/open-filmly-agent-live-e2e');
  await directory.create(recursive: true);
  await File('${directory.path}/$name.png').writeAsBytes(base64Decode(value));
}
