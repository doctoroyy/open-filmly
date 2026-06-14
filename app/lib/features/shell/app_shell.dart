import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../widgets/global_search.dart';
import '../../core/platform/window_channel.dart';

/// Persistent macOS-style split view: a light sidebar on the left (brand +
/// library nav) and the routed content on the right — matching NetEase 爆米花's
/// Mac layout. Also hosts the Cmd/Ctrl+F search shortcut + startup auto-scan.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _navItems = <_NavItem>[
    _NavItem(icon: Icons.home_rounded, label: '首页', path: '/'),
    _NavItem(icon: Icons.history_rounded, label: '最近观看', path: '/recent'),
    _NavItem(icon: Icons.movie_rounded, label: '电影', path: '/movies'),
    _NavItem(icon: Icons.tv_rounded, label: '电视剧', path: '/tv'),
    _NavItem(icon: Icons.animation_rounded, label: '动漫', path: '/anime'),
    _NavItem(icon: Icons.live_tv_rounded, label: '综艺', path: '/variety'),
    _NavItem(icon: Icons.music_note_rounded, label: '演唱会', path: '/concert'),
    _NavItem(icon: Icons.menu_book_rounded, label: '纪录片', path: '/documentary'),
    _NavItem(icon: Icons.more_horiz_rounded, label: '其他', path: '/other'),
    _NavItem(icon: Icons.dns_rounded, label: '来源', path: '/sources'),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const double _sidebarWidth = 212;

  bool _startupScanStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupScan());
  }

  Future<void> _runStartupScan() async {
    if (_startupScanStarted) return;
    _startupScanStarted = true;
    try {
      final config = await ref.read(configProvider.future);
      final result = await ref.read(libraryAutoScanProvider).run(config);
      if (!mounted || !result.hasChanges) return;
      invalidateLibraryViews(ref);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            '已自动更新媒体库：新增 ${result.importedItems} 项'
            '${result.enrichedItems > 0 ? '，补全元数据 ${result.enrichedItems} 项' : ''}',
          ),
        ),
      );
    } catch (_) {
      // best-effort
    }
  }

  String _location(BuildContext context) => GoRouterState.of(context).uri.path;

  int _selectedIndex(BuildContext context) {
    final location = _location(context);
    for (var i = AppShell._navItems.length - 1; i >= 0; i--) {
      final path = AppShell._navItems[i].path;
      if (path == '/') {
        if (location == '/') return i;
      } else if (location.startsWith(path)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);
    final settingsSelected = _location(context).startsWith('/config');

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const _OpenSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _OpenSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (_) {
              GlobalSearch.show(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: FilmlyPalette.background,
            body: Stack(
              children: [
                Row(
                  children: [
                    _Sidebar(
                      selectedIndex: selected,
                      settingsSelected: settingsSelected,
                      onTapItem: (i) => context.go(AppShell._navItems[i].path),
                      onTapSettings: () => context.go('/config'),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: FilmlyPalette.divider,
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
                if (Theme.of(context).platform == TargetPlatform.macOS)
                  Positioned(
                    top: 0,
                    left: WindowChromeMetrics.macOSTrafficLightReservedWidth,
                    width:
                        _sidebarWidth -
                        WindowChromeMetrics.macOSTrafficLightReservedWidth,
                    height: WindowChromeMetrics.macOSTitlebarHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () {
                        WindowChannel.maximize();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.settingsSelected,
    required this.onTapItem,
    required this.onTapSettings,
  });

  final int selectedIndex;
  final bool settingsSelected;
  final ValueChanged<int> onTapItem;
  final VoidCallback onTapSettings;

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return Container(
      width: _AppShellState._sidebarWidth,
      color: FilmlyPalette.sidebar,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            isMac ? WindowChromeMetrics.macOSTitlebarHeight : 16,
            12,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: FilmlyPalette.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Open Filmly',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: FilmlyPalette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Search Field Placeholder — triggers GlobalSearch on click
              GestureDetector(
                onTap: () => GlobalSearch.show(context),
                child: Container(
                  height: 32,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: FilmlyPalette.divider),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: FilmlyPalette.textMuted,
                        size: 15,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '输入影片名称搜索',
                        style: TextStyle(
                          color: FilmlyPalette.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.only(left: 10, bottom: 6),
                child: Text(
                  '媒体库',
                  style: TextStyle(
                    color: FilmlyPalette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: AppShell._navItems.length,
                  itemBuilder: (context, i) {
                    final item = AppShell._navItems[i];
                    return _SidebarItem(
                      key: Key('sidebar_${item.path}'),
                      icon: item.icon,
                      label: item.label,
                      selected: i == selectedIndex && !settingsSelected,
                      onTap: () => onTapItem(i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: FilmlyPalette.divider),
              const SizedBox(height: 10),
              // Account Row & Settings Icon at the bottom (Netease style)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: FilmlyPalette.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: FilmlyPalette.divider),
                      ),
                      child: const Center(
                        child: Text(
                          'X',
                          style: TextStyle(
                            color: FilmlyPalette.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Filmly',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: FilmlyPalette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: const Key('sidebar_/config'),
                      onTap: onTapSettings,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: settingsSelected
                              ? FilmlyPalette.accent.withValues(alpha: 0.12)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          color: settingsSelected
                              ? FilmlyPalette.accent
                              : FilmlyPalette.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? FilmlyPalette.accent.withValues(alpha: 0.12)
        : (_hovered ? FilmlyPalette.surfaceStrong : Colors.transparent);
    final fg = widget.selected
        ? FilmlyPalette.accent
        : FilmlyPalette.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 17, color: fg),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}
