import 'package:flutter/material.dart';

import 'filmly_design.dart';

/// Consistent, Apple-styled error state with an optional retry action.
///
/// Used in place of bare error text in `AsyncValue.when(error: ...)` branches
/// so network/database failures always offer the user a way forward.
class FilmlyErrorState extends StatelessWidget {
  const FilmlyErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  /// When true, renders a tighter inline layout for small surfaces (shelves).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: FilmlyPalette.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: FilmlyPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: FilmlyPalette.surface,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(icon, size: 32, color: FilmlyPalette.textMuted),
            ),
            const SizedBox(height: 18),
            const Text(
              '出错了',
              style: TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FilmlyPalette.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilmlyGlassButton(
                label: '重试',
                icon: Icons.refresh_rounded,
                accent: true,
                onTap: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
