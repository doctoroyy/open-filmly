import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/platform/window_channel.dart';
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
  final _host = PlayerHostHandle();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_configureWindow());
  }

  Future<void> _configureWindow() async {
    if (!PlatformCapabilities.isDesktop) return;
    // Intercept the red traffic-light so we can stop audio first.
    await windowManager.setPreventClose(true);
    await windowManager.setTitle(widget.args.title);
    await windowManager.setBackgroundColor(const Color(0xFF000000));
  }

  @override
  void onWindowClose() {
    unawaited(_closePlayerWindow());
  }

  Future<void> _closePlayerWindow() async {
    if (_closing) return;
    _closing = true;
    // 1) Stop VLC so audio does not continue after the window is gone.
    try {
      await _host.stopPlayback?.call();
    } catch (_) {}
    // 2) Close only this NSWindow — never windowManager.destroy()
    //    (that calls NSApp.terminate and kills the library too).
    try {
      await windowManager.setPreventClose(false);
    } catch (_) {}
    await WindowChannel.closeCurrentWindow();
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
        host: _host,
        onClose: () => unawaited(_closePlayerWindow()),
      ),
    );
  }
}
