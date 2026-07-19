import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/player_page.dart';
import 'platform_capabilities.dart';
import 'player_window.dart';

/// Opens media playback with the correct desktop/mobile presentation.
///
/// - **Desktop:** spawns a true independent OS process/window (爆米花 style).
/// - **Mobile:** pushes the in-app `/player` route.
Future<void> openPlayer(BuildContext context, PlayerArgs args) async {
  if (PlatformCapabilities.isDesktop) {
    await PlayerWindowLauncher.open(args);
    return;
  }
  if (!context.mounted) return;
  context.push('/player', extra: args);
}
