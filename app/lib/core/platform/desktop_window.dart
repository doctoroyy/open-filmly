import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'platform_capabilities.dart';

abstract final class DesktopWindow {
  static Future<void> initialize() async {
    if (!PlatformCapabilities.isDesktop) return;

    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(960, 640));
    await windowManager.setTitle('Open Filmly');
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
  }

  static Future<void> afterFirstFrame() async {
    if (!PlatformCapabilities.isDesktop) return;
    final size = await windowManager.getSize();
    if (size.width < 960 || size.height < 640) {
      await windowManager.setSize(const Size(1280, 800));
      await windowManager.center();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> toggleMaximize() async {
    if (!PlatformCapabilities.isDesktop) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  static Future<void> toggleFullScreen() async {
    if (!PlatformCapabilities.isDesktop) return;
    await windowManager.setFullScreen(!(await windowManager.isFullScreen()));
  }

  static Future<void> minimize() async {
    if (PlatformCapabilities.isDesktop) await windowManager.minimize();
  }
}
