import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/player_page.dart';
import 'platform_capabilities.dart';
import 'player_window.dart';

/// Opens media playback with the correct desktop/mobile presentation.
///
/// - **Desktop:** spawns a secondary window in the same process (爆米花 style).
/// - **Mobile:** pushes the in-app `/player` route.
Future<void> openPlayer(BuildContext context, PlayerArgs args) async {
  if (PlatformCapabilities.isDesktop) {
    await PlayerWindowLauncher.open(args);
    return;
  }
  if (!context.mounted) return;
  context.push('/player', extra: args);
}

/// Runs [action] (typically resolve source + [openPlayer]) under a lightweight
/// launch spinner so the gap before the player window appears isn't silent.
Future<T> withPlayerLaunchLoading<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  if (!context.mounted) return action();

  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (ctx) {
      return PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: const Color(0xF01C1C1E),
            borderRadius: BorderRadius.circular(16),
            elevation: 12,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    '正在打开…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ).whenComplete(() => dialogOpen = false);

  try {
    return await action();
  } finally {
    if (dialogOpen && navigator.mounted) {
      navigator.pop();
    }
  }
}
