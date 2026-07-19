import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_skill/flutter_skill.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/platform/desktop_window.dart';
import 'core/platform/player_window.dart';
import 'features/player/player_app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized();
  }

  // Same-process multi-window: each window has its own engine.
  final windowController = await WindowController.fromCurrentEngine();
  final businessId = PlayerWindowLauncher.businessIdFromArguments(
    windowController.arguments,
  );

  if (businessId == kPlayerWindowBusinessId) {
    final playerArgs = PlayerWindowLauncher.playerArgsFromArguments(
      windowController.arguments,
    );
    if (playerArgs == null || playerArgs.uri.isEmpty) {
      // Broken player window — close quietly.
      return;
    }

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1100, 640),
      minimumSize: Size(800, 480),
      center: true,
      backgroundColor: Colors.black,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setTitle(playerArgs.title);
      await windowManager.setBackgroundColor(Colors.black);
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(ProviderScope(child: OpenFilmlyPlayerApp(args: playerArgs)));
    return;
  }

  // Main library window.
  await DesktopWindow.initialize();
  runApp(const ProviderScope(child: OpenFilmlyApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(DesktopWindow.afterFirstFrame());
  });
}
