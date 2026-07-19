import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/platform_capabilities.dart';
import 'player_page.dart';

/// Standalone player process UI — no media-library shell, no back stack.
/// Closing the window exits this process and leaves the library instance alone.
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
    _configureWindow();
  }

  Future<void> _configureWindow() async {
    if (!PlatformCapabilities.isDesktop) return;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await windowManager.setTitle(widget.args.title);
    await windowManager.setMinimumSize(const Size(960, 540));
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.setBackgroundColor(const Color(0xFF000000));
    // Slightly smaller than library default — feels like a player window.
    await windowManager.setSize(const Size(1280, 720));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    // Exit this player process only; the library app is a separate process.
    unawaited(_closePlayerProcess());
  }

  Future<void> _closePlayerProcess() async {
    try {
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
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
        // Independent window: back / Esc closes the process.
        onClose: () => exit(0),
      ),
    );
  }
}
