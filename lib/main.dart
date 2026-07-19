import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_skill/flutter_skill.dart';

import 'app.dart';
import 'core/platform/desktop_window.dart';
import 'core/platform/player_window.dart';
import 'features/player/player_app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized();
  }

  // Independent player process (desktop): `open -n … --args --player-file=…`
  final playerFile = PlayerWindowLauncher.playerArgsFileFrom(args) ??
      PlayerWindowLauncher.playerArgsFileFrom(Platform.executableArguments);
  if (playerFile != null) {
    final playerArgs = await PlayerWindowLauncher.loadPlayerArgs(playerFile);
    if (playerArgs != null && playerArgs.uri.isNotEmpty) {
      runApp(ProviderScope(child: OpenFilmlyPlayerApp(args: playerArgs)));
      return;
    }
  }

  await DesktopWindow.initialize();
  runApp(const ProviderScope(child: OpenFilmlyApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(DesktopWindow.afterFirstFrame());
  });
}
