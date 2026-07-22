import 'dart:convert';
import 'dart:io';

import 'package:flutter_skill/src/drivers/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the user-configured cloud provider through the running macOS app.
/// This stops after Gemini returns a reviewable plan: it never confirms or
/// executes a media operation.
void main() {
  final vmUri = Platform.environment['FLUTTER_SKILL_URI']?.trim() ?? '';
  final enabled =
      Platform.environment['FILMLY_AGENT_LIVE_E2E'] == '1' &&
      vmUri.startsWith('ws://');

  test(
    'creates a reviewable Agent plan with the configured Gemini provider',
    () async {
      final client = FlutterSkillClient(vmUri);
      addTearDown(client.disconnect);
      await client.connect();

      await client.tap(key: 'sidebar_/agent');
      await _waitFor(client, 'agent_request_input');
      await _saveScreenshot(client, '01-agent-ready');

      await client.tap(key: 'agent_request_input');
      await client.enterText('agent_request_input', '把没看过的科幻片建个合集');
      final entered = await client.getTextValue('agent_request_input');
      if (entered?.contains('科幻片') != true) {
        throw StateError('The Agent request field did not receive the prompt');
      }
      await client.tap(key: 'agent_gemini_plan_button');
      final completedKey = await _waitForAny(client, const [
        'agent_plan_panel',
        'agent_error_text',
      ], timeout: const Duration(seconds: 60));
      if (completedKey == 'agent_error_text') {
        await _saveScreenshot(client, '02-gemini-error');
        throw StateError('Gemini Agent planning failed in the real app');
      }
      await _saveScreenshot(client, '02-gemini-plan');
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip: enabled
        ? false
        : 'Set FILMLY_AGENT_LIVE_E2E=1 and FLUTTER_SKILL_URI to run a live provider test.',
  );

  test(
    'captures the existing reviewable Agent plan without another provider call',
    () async {
      final client = FlutterSkillClient(vmUri);
      addTearDown(client.disconnect);
      await client.connect();

      await _waitFor(client, 'agent_plan_panel');
      await client.scrollTo(key: 'agent_plan_panel');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _saveScreenshot(client, '03-gemini-plan-focused');
    },
    timeout: const Timeout(Duration(seconds: 20)),
    skip: enabled
        ? false
        : 'Set FILMLY_AGENT_LIVE_E2E and FLUTTER_SKILL_URI to capture a live plan.',
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

Future<void> _saveScreenshot(FlutterSkillClient client, String name) async {
  final value = await client.takeScreenshot();
  if (value == null) throw StateError('Could not capture screenshot: $name');
  final directory = Directory('/tmp/open-filmly-agent-live-e2e');
  await directory.create(recursive: true);
  await File('${directory.path}/$name.png').writeAsBytes(base64Decode(value));
}
