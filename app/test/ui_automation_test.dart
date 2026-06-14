import 'dart:convert';
import 'dart:io';
import 'package:flutter_skill/src/drivers/flutter_driver.dart';

void log(String msg) {
  stdout.writeln(msg);
}

void main() async {
  if (!Platform.script.path.endsWith('ui_automation_test.dart')) {
    log('Skipping standalone UI automation runner under flutter test.');
    return;
  }

  final env = Platform.environment;
  String requireEnv(String key) {
    final value = env[key];
    if (value == null || value.isEmpty) {
      throw Exception(
        'Set $key before running the standalone UI automation test.',
      );
    }
    return value;
  }

  final smbHost = requireEnv('OPEN_FILMLY_UI_SMB_HOST');
  final smbUsername = requireEnv('OPEN_FILMLY_UI_SMB_USERNAME');
  final smbPassword = requireEnv('OPEN_FILMLY_UI_SMB_PASSWORD');
  final smbShare = requireEnv('OPEN_FILMLY_UI_SMB_SHARE');
  final smbVideoName = requireEnv('OPEN_FILMLY_UI_VIDEO_NAME');
  final smbShareInput = env['OPEN_FILMLY_UI_SMB_SHARE_INPUT'] ?? '';

  log('=== STARTING AUTOMATED UI TEST CLOSED LOOP ===');

  final screenshotDir = Directory(
    env['FILMLY_UI_SCREENSHOT_DIR'] ?? 'test/screenshots',
  );
  await screenshotDir.create(recursive: true);

  // 1. Resolve Dart VM Service URI
  String? uri;
  final uriFile = File('.flutter_skill_uri');
  if (uriFile.existsSync()) {
    uri = uriFile.readAsStringSync().trim();
  }

  // Fallback to default vm service port 50000 if not found
  if (uri == null || !uri.startsWith('ws://')) {
    log(
      'No valid .flutter_skill_uri found. Reading from default vm service port 50000...',
    );
    uri = 'ws://127.0.0.1:50000/EaMyQLOLwYs=/ws';
  }

  log('Connecting to VM Service at: $uri');
  final client = FlutterSkillClient(uri);
  await client.connect();
  log('✅ Successfully connected to Flutter App VM Service!');

  // Helper for screenshot
  Future<void> takeScreenshot(String name) async {
    try {
      final imageBase64 = await client.takeScreenshot().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          log('⚠️ Take screenshot timed out for $name');
          return null;
        },
      );
      if (imageBase64 != null) {
        final path = '${screenshotDir.path}/$name.png';
        await File(path).writeAsBytes(base64Decode(imageBase64));
        log('📸 Screenshot saved to $path');
      } else {
        log('⚠️ Take screenshot returned null');
      }
    } catch (e) {
      log('⚠️ Failed to take screenshot: $e');
    }
  }

  Future<bool> hasKey(String key) async {
    try {
      return await client.getWidgetProperties(key) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> waitForKey(
    String key, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await hasKey(key)) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw Exception('Timed out waiting for widget key: $key');
  }

  Future<bool> tryTap(
    String key, {
    Duration settle = const Duration(milliseconds: 800),
  }) async {
    try {
      final result = await client
          .tap(key: key)
          .timeout(const Duration(seconds: 2));
      if (result['success'] == false) return false;
      await Future.delayed(settle);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> tapRequired(
    String key, {
    Duration settle = const Duration(milliseconds: 800),
  }) async {
    final result = await client
        .tap(key: key)
        .timeout(const Duration(seconds: 3));
    if (result['success'] == false) {
      throw Exception('Failed to tap required widget key: $key ($result)');
    }
    await Future.delayed(settle);
  }

  Future<void> enterTextRequired(String key, String text) async {
    final result = await client
        .enterText(key, text)
        .timeout(const Duration(seconds: 3));
    if (result['success'] == false) {
      throw Exception('Failed to enter text into required widget key: $key');
    }
  }

  Future<void> doubleTapRequired(String key) async {
    final ok = await client
        .doubleTap(key: key)
        .timeout(const Duration(seconds: 3));
    if (!ok) {
      throw Exception('Failed to double tap required widget key: $key');
    }
  }

  Future<String> waitForAnyKey(
    List<String> keys, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final key in keys) {
        if (await hasKey(key)) return key;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw Exception('Timed out waiting for any widget key: ${keys.join(', ')}');
  }

  Future<bool> hasText(String needle) async {
    try {
      final texts = await client.getTextContent();
      return texts.any((entry) => entry.toString().contains(needle));
    } catch (_) {
      return false;
    }
  }

  Future<bool> waitUntil(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return true;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  Future<void> leavePlayerIfVisible() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      if (!await hasKey('player_center_gesture') &&
          !await hasKey('player_back_button')) {
        return;
      }

      try {
        await client.pressKey('escape').timeout(const Duration(seconds: 2));
        await Future.delayed(const Duration(milliseconds: 2200));
      } catch (_) {
        // Continue with pointer-based fallbacks.
      }

      if (!await hasKey('player_center_gesture')) return;

      if (await hasKey('player_back_button')) {
        if (await tryTap(
          'player_back_button',
          settle: const Duration(milliseconds: 2200),
        )) {
          if (!await hasKey('player_center_gesture')) return;
        }
      }

      if (await hasKey('player_center_gesture') &&
          !await hasKey('player_back_button')) {
        await tryTap(
          'player_center_gesture',
          settle: const Duration(milliseconds: 900),
        );
        continue;
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    throw Exception('Player was still visible after exit attempts');
  }

  Future<void> navigateToSourcesPage() async {
    await leavePlayerIfVisible();

    if (await hasKey('source_card_smb')) return;

    if (await hasKey('sidebar_/sources')) {
      await tapRequired(
        'sidebar_/sources',
        settle: const Duration(milliseconds: 1200),
      );
      if (await hasKey('source_card_smb')) return;
    }

    if (await hasKey('smb_back_button')) {
      log('SMB page is visible at startup. Returning to sources page first...');
      await tryTap(
        'smb_back_button',
        settle: const Duration(milliseconds: 1200),
      );
      if (await hasKey('source_card_smb')) return;
    }

    if (!await hasKey('home_add_source_button')) {
      log('Home add-source button not visible. Returning to home first...');
      await waitForKey('sidebar_/', timeout: const Duration(seconds: 8));
      await tapRequired(
        'sidebar_/',
        settle: const Duration(milliseconds: 1200),
      );
    }

    if (!await waitUntil(() => hasKey('home_add_source_button'))) {
      await leavePlayerIfVisible();
    }

    await waitForKey(
      'home_add_source_button',
      timeout: const Duration(seconds: 8),
    );
    await tapRequired(
      'home_add_source_button',
      settle: const Duration(milliseconds: 1200),
    );
    await waitForKey('source_card_smb', timeout: const Duration(seconds: 8));
  }

  try {
    // Step 1: Navigate to Sources page from any common starting route.
    log('Step 1: Navigating to Sources page...');
    await navigateToSourcesPage();
    await takeScreenshot('ui_step1_sources');

    // Step 2: Click SMB Card
    log('Step 2: Clicking SMB card...');
    await waitForKey('source_card_smb');
    await tapRequired(
      'source_card_smb',
      settle: const Duration(milliseconds: 1200),
    );
    await waitForAnyKey([
      'smb_host_input',
      'smb_disconnect_button',
      'entry_$smbShare',
    ], timeout: const Duration(seconds: 8));
    await takeScreenshot('ui_step2_smb_form');

    // Step 3: Check connection state. If already connected, disconnect to force reconnect and credential saving.
    log('Step 3: Checking connection state...');
    bool hasDisconnectBtn = false;
    try {
      final properties = await client.getWidgetProperties(
        'smb_disconnect_button',
      );
      if (properties != null) {
        hasDisconnectBtn = true;
      }
    } catch (_) {}

    if (hasDisconnectBtn) {
      log(
        'Already connected to SMB. Tapping disconnect button to force reconnect & credential saving...',
      );
      await tapRequired(
        'smb_disconnect_button',
        settle: const Duration(milliseconds: 1500),
      );
      await waitForKey('smb_host_input', timeout: const Duration(seconds: 8));
      await takeScreenshot('ui_step3_disconnected');
    }

    log('Entering connection credentials...');
    await waitForKey('smb_host_input', timeout: const Duration(seconds: 8));
    await enterTextRequired('smb_host_input', smbHost);
    await enterTextRequired('smb_share_input', smbShareInput);
    await enterTextRequired('smb_user_input', smbUsername);
    await enterTextRequired('smb_pass_input', smbPassword);
    await takeScreenshot('ui_step3_filled');

    log('Clicking connect button to submit connection...');
    await tapRequired('smb_connect_button');
    if (!await waitUntil(
      () => hasKey('entry_$smbShare'),
      timeout: const Duration(seconds: 12),
    )) {
      if (await hasKey('smb_connect_button')) {
        log('Connection entry not visible yet. Retrying connect tap...');
        await tapRequired('smb_connect_button');
      }
      await waitForKey('entry_$smbShare', timeout: const Duration(seconds: 12));
    }
    await takeScreenshot('ui_step4_connected');

    // Step 4: Click configured share.
    log('Step 4: Clicking entry_$smbShare to enter SMB share...');
    await tapRequired(
      'entry_$smbShare',
      settle: const Duration(milliseconds: 1500),
    );
    await waitForKey(
      'entry_$smbVideoName',
      timeout: const Duration(seconds: 12),
    );
    await takeScreenshot('ui_step5_wd_folder');

    log('Step 5: Clicking video file entry to start playback...');
    await tapRequired(
      'entry_$smbVideoName',
      settle: const Duration(milliseconds: 1200),
    );
    await waitForKey(
      'player_center_gesture',
      timeout: const Duration(seconds: 12),
    );

    // Step 6: Test Double Tap to Fullscreen (using SDK doubleTap method)
    log('Step 6: Double tapping center gesture zone to toggle fullscreen...');
    await doubleTapRequired('player_center_gesture');
    log('Double tap event sent via SDK. Waiting 2 seconds...');
    await Future.delayed(const Duration(seconds: 2));

    // Step 7: Exit player (Double tap to exit fullscreen first, then wake up controls and back out)
    log('Step 7: Double tapping to exit fullscreen...');
    await doubleTapRequired('player_center_gesture');
    await Future.delayed(const Duration(seconds: 2));
    log('Tapping player back button...');
    await leavePlayerIfVisible();
    if (!await waitUntil(
      () async => !await hasKey('player_center_gesture'),
      timeout: const Duration(seconds: 8),
    )) {
      await leavePlayerIfVisible();
    }
    await waitForKey('smb_back_button', timeout: const Duration(seconds: 8));

    // Step 8: Test Auto-Save and Prefill
    log(
      'Step 8: Testing auto-save and prefill. Backing out of current SMB directory...',
    );
    log('Navigating back to Sources page...');
    await tapRequired(
      'smb_back_button',
      settle: const Duration(milliseconds: 1500),
    );
    await waitForKey('source_card_smb', timeout: const Duration(seconds: 8));

    log('Entering SMB configuration page again to check prefill...');
    await tapRequired(
      'source_card_smb',
      settle: const Duration(milliseconds: 1200),
    );
    await waitForAnyKey([
      'smb_host_input',
      'smb_disconnect_button',
    ], timeout: const Duration(seconds: 8));
    await takeScreenshot('ui_step9_prefill_check');

    var hostInputVisible = false;
    try {
      hostInputVisible =
          await client.getWidgetProperties('smb_host_input') != null;
    } catch (_) {}

    if (!hostInputVisible) {
      var disconnectVisible = false;
      try {
        disconnectVisible =
            await client.getWidgetProperties('smb_disconnect_button') != null;
      } catch (_) {}

      if (disconnectVisible) {
        log(
          'SMB page is still connected. Disconnecting before prefill check...',
        );
        await tapRequired(
          'smb_disconnect_button',
          settle: const Duration(milliseconds: 1500),
        );
        await waitForKey('smb_host_input', timeout: const Duration(seconds: 8));
        await takeScreenshot('ui_step9b_prefill_after_disconnect');
      }
    }

    // Retrieve prefilled host value
    final prefilledHost = await client.getTextValue('smb_host_input');
    log('Prefilled Host value is: "$prefilledHost"');

    if (prefilledHost == smbHost) {
      log(
        '✅ Prefill Verification SUCCESS! Configuration was successfully persisted and prefilled.',
      );
    } else {
      throw Exception(
        'Prefill Verification FAILED! Expected "$smbHost" but got "$prefilledHost"',
      );
    }

    // Step 9: Test Re-Match metadata UI Flow
    log('Step 9: Exiting SMB form and going to TV Shows library...');
    await tapRequired('smb_back_button');
    await waitForKey('source_card_smb', timeout: const Duration(seconds: 8));

    await tapRequired('sidebar_/tv');
    log('Waiting 2 seconds for TV Shows grid to load...');
    final targetTvKey = await waitForAnyKey([
      'library_media_The Witcher',
      'library_media_怪奇物语',
    ], timeout: const Duration(seconds: 8));
    await takeScreenshot('ui_step10_tv_grid');

    // Step 10: Click target TV Show card
    log('Step 10: Tapping target TV Show card...');
    await tapRequired(targetTvKey, settle: const Duration(milliseconds: 1200));
    await waitForKey(
      'detail_re-match_button',
      timeout: const Duration(seconds: 8),
    );
    await takeScreenshot('ui_step11_details_page');

    // Step 11: Trigger Re-Match dialog
    log('Step 11: Tapping Re-Match button...');
    await tapRequired('detail_re-match_button');
    log('Waiting 1.5 seconds for Re-Match dialog to slide in...');
    await Future.delayed(const Duration(milliseconds: 1500));
    await takeScreenshot('ui_step12_re-match_dialog');

    // Step 12: Check if TMDB API Key is configured
    log('Step 12: Inspecting Re-Match dialog state...');
    bool isApiKeyConfigured = false;
    try {
      final properties = await client.getWidgetProperties(
        're-match_search_input',
      );
      if (properties != null) {
        isApiKeyConfigured = true;
      }
    } catch (_) {
      // Widget not found means API key is missing
    }

    if (isApiKeyConfigured) {
      log('TMDB API Key is configured! Entering search term and searching...');
      await enterTextRequired('re-match_search_input', 'The Witcher');
      await tapRequired('re-match_search_button');
      log('Waiting 3 seconds for search results...');
      await waitForKey(
        're-match_result_0',
        timeout: const Duration(seconds: 8),
      );
      await takeScreenshot('ui_step13_search_results');

      log('Tapping first search result to apply match...');
      await tapRequired('re-match_result_0');
      log(
        'Waiting 4 seconds for metadata synchronization and detail reload...',
      );
      await Future.delayed(const Duration(seconds: 4));
      await takeScreenshot('ui_step14_re-matched_details');
      log('✅ Manual Re-Match flow completed and verified with API key!');
    } else {
      log(
        '⚠️ TMDB API Key is not configured in this test environment. Verifying correct fallback message...',
      );
      if (!await hasText('未配置 TMDB API 密钥')) {
        throw Exception('Missing expected TMDB API key fallback message');
      }
      await takeScreenshot('ui_step13_missing_api_key');
      log('Tapping close button on dialog...');
      // Pop dialog by clicking close button or tapping outside/ESC
      await client.pressKey('escape');
      await Future.delayed(const Duration(milliseconds: 800));
      log(
        '✅ Fallback verification success! Correctly showed "未配置 TMDB API 密钥".',
      );
    }

    log(
      '🎉🎉🎉 ALL AUTOMATED UI TESTS PASSED SUCCESSFULLY! CLOSED LOOP COMPLETE! 🎉🎉🎉',
    );
  } catch (e, stack) {
    log('❌ UI Test Failed: $e');
    log(stack.toString());
    exit(1);
  } finally {
    await client.disconnect();
  }
}
