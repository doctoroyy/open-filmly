import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../../features/player/player_page.dart';
import 'platform_capabilities.dart';

/// Business id embedded in [WindowConfiguration.arguments] JSON.
const kPlayerWindowBusinessId = 'player';
const kMainWindowBusinessId = 'main';

/// Opens a **secondary window in the same app process** for playback
/// (NetEase 爆米花: one Dock icon, library stays, player is a separate
/// video window — NOT a second full application instance).
abstract final class PlayerWindowLauncher {
  static String businessIdFromArguments(String? arguments) {
    if (arguments == null || arguments.isEmpty) return kMainWindowBusinessId;
    try {
      final map = jsonDecode(arguments);
      if (map is Map && map['businessId'] is String) {
        return map['businessId'] as String;
      }
    } catch (_) {}
    if (arguments == kPlayerWindowBusinessId) return kPlayerWindowBusinessId;
    return kMainWindowBusinessId;
  }

  static PlayerArgs? playerArgsFromArguments(String? arguments) {
    if (arguments == null || arguments.isEmpty) return null;
    try {
      final map = jsonDecode(arguments);
      if (map is! Map<String, dynamic>) return null;
      if (map['businessId'] != kPlayerWindowBusinessId) return null;
      final payload = map['payload'];
      if (payload is Map<String, dynamic>) {
        return PlayerArgs.fromJson(payload);
      }
      return PlayerArgs.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Create a player window (same process, second NSWindow).
  static Future<void> open(PlayerArgs args) async {
    if (!PlatformCapabilities.isDesktop || kIsWeb) {
      throw StateError('PlayerWindowLauncher is desktop-only');
    }

    final argument = jsonEncode({
      'businessId': kPlayerWindowBusinessId,
      'payload': args.toJson(),
    });

    // Close any existing player window so we don't stack many.
    try {
      final all = await WindowController.getAll();
      for (final c in all) {
        if (businessIdFromArguments(c.arguments) == kPlayerWindowBusinessId) {
          try {
            await c.hide();
            // Best-effort close via window method if exposed.
            await c.invokeMethod('window_close');
          } catch (_) {}
        }
      }
    } catch (_) {}

    final controller = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: argument),
    );
    await controller.show();
  }
}
