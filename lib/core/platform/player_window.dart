import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../features/player/player_page.dart';
import 'platform_capabilities.dart';

/// Launches (and detects) a **true** separate OS process window for desktop
/// playback — matching NetEase 爆米花's independent player window model.
///
/// On macOS we use `open -n -a … --args --player-file=…` so the library app
/// stays open while a second Open Filmly instance runs only the player.
abstract final class PlayerWindowLauncher {
  static const argPrefix = '--player-file=';

  /// If this process was started as a player window, returns the args file path.
  static String? playerArgsFileFrom(List<String> args) {
    for (final arg in args) {
      if (arg.startsWith(argPrefix)) {
        return arg.substring(argPrefix.length);
      }
    }
    return null;
  }

  static Future<PlayerArgs?> loadPlayerArgs(String filePath) async {
    try {
      final raw = await File(filePath).readAsString();
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return PlayerArgs.fromJson(map);
    } catch (_) {
      return null;
    } finally {
      try {
        await File(filePath).delete();
      } catch (_) {}
    }
  }

  /// Opens an independent player process on desktop. No-op payload on mobile
  /// (caller should push the in-app route instead).
  static Future<void> open(PlayerArgs args) async {
    if (!PlatformCapabilities.isDesktop || kIsWeb) {
      throw StateError('PlayerWindowLauncher is desktop-only');
    }

    final dir = Directory.systemTemp;
    final file = File(
      p.join(
        dir.path,
        'open_filmly_player_${DateTime.now().microsecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(jsonEncode(args.toJson()), flush: true);

    if (Platform.isMacOS) {
      final appPath = _macAppBundlePath();
      final result = await Process.start('open', [
        '-n', // new instance
        '-a',
        appPath,
        '--args',
        '$argPrefix${file.path}',
      ], mode: ProcessStartMode.detached);
      unawaited(result.exitCode);
      return;
    }

    // Windows / Linux: re-exec the binary with the player arg.
    await Process.start(Platform.resolvedExecutable, [
      '$argPrefix${file.path}',
    ], mode: ProcessStartMode.detached);
  }

  static String _macAppBundlePath() {
    // …/Open Filmly.app/Contents/MacOS/open_filmly → …/Open Filmly.app
    final exe = Platform.resolvedExecutable;
    final marker = '/Contents/MacOS/';
    final idx = exe.indexOf(marker);
    if (idx > 0) return exe.substring(0, idx);
    return exe;
  }
}
