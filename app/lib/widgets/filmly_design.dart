import 'package:flutter/material.dart';

/// Shared surfaces and controls, styled to match NetEase 爆米花 (Filmly) on
/// macOS: a native light appearance — white content, a light translucent
/// sidebar, near-black text, black primary buttons, blue progress accent.
class FilmlyPalette {
  /// Main content background — soft, premium light gray to match Filmly's macOS content area.
  static const background = Color(0xFFF3F3F6);

  /// Sidebar background — transparent to let macOS native VisualEffectView (frosted glass) show through.
  static const sidebar = Color(0x00000000);

  /// Subtle fill for cards / inputs / hover states.
  static const surface = Color(0xFFEAEAEE);
  static const surfaceStrong = Color(0xFFE3E3E8);

  /// Hairline divider.
  static const divider = Color(0xFFE2E2E6);

  /// Blue accent — progress bars, selection, links.
  static const accent = Color(0xFF2F6BFF);

  /// Primary action color (black filled buttons, NetEase style).
  static const primary = Color(0xFF1C1C1E);

  static const textPrimary = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF6E6E76);
  static const textMuted = Color(0xFF9A9AA2);
  static const panelShadow = Color(0x1A000000);
}

class FilmlyGlassPanel extends StatelessWidget {
  const FilmlyGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color = FilmlyPalette.surface,
    this.blur = 22,
    this.boxShadow,
    this.width,
    this.height,
    this.alignment,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color color;
  final double blur;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: FilmlyPalette.divider),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}

class FilmlyGlassButton extends StatefulWidget {
  const FilmlyGlassButton({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.accent = false,
    this.selected = false,
    this.height = 44,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool accent;
  final bool selected;
  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? foregroundColor;

  @override
  State<FilmlyGlassButton> createState() => _FilmlyGlassButtonState();
}

class _FilmlyGlassButtonState extends State<FilmlyGlassButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    // Accent = black filled (NetEase primary). Plain = light gray.
    final Color background;
    final Color foreground;
    if (widget.accent) {
      background = enabled
          ? (_hovered ? const Color(0xFF333336) : FilmlyPalette.primary)
          : FilmlyPalette.surfaceStrong;
      foreground =
          widget.foregroundColor ??
          (enabled ? Colors.white : FilmlyPalette.textMuted);
    } else {
      background = widget.selected
          ? FilmlyPalette.accent.withValues(alpha: 0.12)
          : (_hovered && enabled
                ? FilmlyPalette.surfaceStrong
                : FilmlyPalette.surface);
      foreground =
          widget.foregroundColor ??
          (!enabled
              ? FilmlyPalette.textMuted
              : widget.selected
              ? FilmlyPalette.accent
              : FilmlyPalette.textPrimary);
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        key: widget.key,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(widget.radius),
            border: widget.accent
                ? null
                : Border.all(color: FilmlyPalette.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 10),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 10),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FilmlyIconButton extends StatefulWidget {
  const FilmlyIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.radius = 12,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double radius;

  @override
  State<FilmlyIconButton> createState() => _FilmlyIconButtonState();
}

class _FilmlyIconButtonState extends State<FilmlyIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? FilmlyPalette.surfaceStrong
                : FilmlyPalette.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: FilmlyPalette.divider),
          ),
          child: Icon(
            widget.icon,
            color: enabled
                ? FilmlyPalette.textPrimary
                : FilmlyPalette.textMuted,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class FilmlyInlineHeader extends StatelessWidget {
  const FilmlyInlineHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.leading,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 16)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: FilmlyPalette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: FilmlyPalette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

class FilmlySearchField extends StatelessWidget {
  const FilmlySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.value,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FilmlyPalette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FilmlyPalette.divider),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: FilmlyPalette.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                isCollapsed: true,
              ),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: value.isEmpty ? 0 : 1,
            child: IgnorePointer(
              ignoring: value.isEmpty,
              child: GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FilmlyPalette.surfaceStrong,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: FilmlyPalette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
