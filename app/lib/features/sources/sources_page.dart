import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/filmly_design.dart';

/// Sources management page — shows all supported media source types,
/// similar to Filmly's source picker.
///
/// Supported sources (current and planned):
/// - Local directory (file system folders)
/// - SMB / NAS (network storage)
/// - WebDAV (planned)
/// - Emby / Jellyfin (planned)
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
          children: [
            FilmlyInlineHeader(
              leading: FilmlyIconButton(
                key: const Key('sources_back_button'),
                icon: Icons.chevron_left_rounded,
                onTap: () => _goBack(context),
              ),
              title: '来源管理',
              subtitle: '添加影片来源后，系统会自动扫描并整理你的媒体库。',
            ),
            const SizedBox(height: 28),
            const _SectionTitle('已支持'),
            const SizedBox(height: 16),
            _SourceCard(
              key: const Key('source_card_local'),
              icon: Icons.folder_rounded,
              title: '本地目录',
              subtitle: '添加电脑上的文件夹，扫描其中的影片',
              color: const Color(0xFF66A3FF),
              onTap: () => context.go('/sources/local'),
            ),
            const SizedBox(height: 14),
            _SourceCard(
              key: const Key('source_card_smb'),
              icon: Icons.dns_rounded,
              title: 'SMB / NAS',
              subtitle: '连接局域网内的 NAS 存储（群晖、威联通等）',
              color: const Color(0xFF62D6B4),
              onTap: () => context.go('/smb'),
            ),
            const SizedBox(height: 14),
            _SourceCard(
              key: const Key('source_card_webdav'),
              icon: Icons.cloud_rounded,
              title: 'WebDAV',
              subtitle: '连接 WebDAV 兼容的云存储或 NAS（Alist、坚果云等）',
              color: const Color(0xFF9D8CFF),
              onTap: () => context.go('/webdav'),
            ),
            const SizedBox(height: 14),
            _SourceCard(
              key: const Key('source_card_emby'),
              icon: Icons.videocam_rounded,
              title: 'Emby',
              subtitle: '连接已有的 Emby 媒体服务器',
              color: const Color(0xFF5FD2E8),
              onTap: () => context.go('/emby'),
            ),
            const SizedBox(height: 14),
            _SourceCard(
              key: const Key('source_card_jellyfin'),
              icon: Icons.live_tv_rounded,
              title: 'Jellyfin',
              subtitle: '连接已有的 Jellyfin 媒体服务器',
              color: const Color(0xFFC57DFF),
              onTap: () => context.go('/emby'),
            ),
            const SizedBox(height: 34),
            const _SectionTitle('即将支持'),
            const SizedBox(height: 16),
            const _SourceCard(
              icon: Icons.cloud_queue_rounded,
              title: '网盘',
              subtitle: '阿里云盘、百度网盘、115 等（规划中）',
              color: Color(0xFFF8B34D),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: FilmlyPalette.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SourceCard extends StatefulWidget {
  const _SourceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final opacity = widget.enabled ? 1.0 : 0.52;

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        key: widget.key,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _hovered && widget.enabled ? -3 : 0,
            0,
          ),
          child: Opacity(
            opacity: opacity,
            child: FilmlyGlassPanel(
              borderRadius: BorderRadius.circular(24),
              color: _hovered
                  ? FilmlyPalette.surfaceStrong
                  : FilmlyPalette.surface,
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: FilmlyPalette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: FilmlyPalette.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.enabled)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: FilmlyPalette.textSecondary,
                      size: 22,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: FilmlyPalette.surfaceStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '规划中',
                        style: TextStyle(
                          color: FilmlyPalette.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
