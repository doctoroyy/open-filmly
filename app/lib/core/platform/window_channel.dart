import 'package:flutter/services.dart';

/// Shared macOS chrome metrics for the transparent titlebar layout.
class WindowChromeMetrics {
  const WindowChromeMetrics._();

  static const double macOSTitlebarHeight = 38;
  static const double macOSTrafficLightReservedWidth = 96;
}

/// Provides a channel to native window manipulation (macOS only).
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
}
