import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/platform_capabilities.dart';
import 'player_page.dart';

/// Secondary-window player UI (same process as the library).
/// Closing this window only destroys the player window — library stays up.
class OpenFilmlyPlayerApp extends ConsumerStatefulWidget {
  const OpenFilmlyPlayerApp({super.key, required this.args});

  final PlayerArgs args;

  @override
  ConsumerState<OpenFilmlyPlayerApp> createState() =>
      _OpenFilmlyPlayerAppState();
}

class _OpenFilmlyPlayerAppState extends ConsumerState<OpenFilmlyPlayerApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_configureWindow());
  }

  Future<void> _configureWindow() async {
    if (!PlatformCapabilities.isDesktop) return;
    await windowManager.setPreventClose(true);
    await windowManager.setTitle(widget.args.title);
    await windowManager.setBackgroundColor(const Color(0xFF000000));
  }

  @override
  void onWindowClose() {
    unawaited(_closePlayerWindow());
  }

  Future<void> _closePlayerWindow() async {
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {
      try {
        await windowManager.close();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.args.title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: PlayerPage(
        args: widget.args,
        onClose: () => unawaited(_closePlayerWindow()),
      ),
    );
  }
}
