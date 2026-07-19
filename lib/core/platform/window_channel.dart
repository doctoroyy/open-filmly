import 'package:flutter/services.dart';

/// Shared macOS chrome metrics for the transparent titlebar layout.
class WindowChromeMetrics {
  const WindowChromeMetrics._();

  static const double macOSTitlebarHeight = 38;
  static const double macOSTrafficLightReservedWidth = 96;
}

/// Provides a channel to native window manipulation.
class WindowChannel {
  static const _channel = MethodChannel('com.openfilmly.window');

  /// Toggles the native fullscreen state of the application window.
  static Future<void> toggleFullScreen() async {
    try {
      await _channel.invokeMethod('toggleFullScreen');
    } catch (e) {
      // Ignore if not implemented on the current platform
    }
  }

  /// Maximizes (zooms) the application window.
  static Future<void> maximize() async {
    try {
      await _channel.invokeMethod('maximize');
    } catch (e) {
      // Ignore if not implemented on the current platform
    }
  }

  /// Closes **only** the current NSWindow (player secondary window).
  ///
  /// Never use [window_manager]'s `destroy()` — on macOS that calls
  /// `NSApp.terminate` and kills the whole app including the library window.
  static Future<void> closeCurrentWindow() async {
    try {
      await _channel.invokeMethod('closeCurrentWindow');
    } catch (e) {
      // Ignore if not implemented
    }
  }
}
