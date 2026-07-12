import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_skill/flutter_skill.dart';

import 'app.dart';
import 'core/platform/desktop_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized();
  }
  await DesktopWindow.initialize();
  runApp(const ProviderScope(child: OpenFilmlyApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(DesktopWindow.afterFirstFrame());
  });
}
