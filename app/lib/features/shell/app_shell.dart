import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/desktop_window.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../data/models/media.dart';
import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../widgets/global_search.dart';

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
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
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
    if (location == '/media') {
      final id = GoRouterState.of(context).uri.queryParameters['id'];
      final media = id == null
          ? null
          : ref.watch(mediaByIdProvider(id)).asData?.value;
      if (media?.type == MediaType.movie) return 2;
      if (media?.type == MediaType.tv) return 3;
      return -1;
    }
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
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            const _OpenSettingsIntent(),
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            const _OpenSettingsIntent(),
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
            const _NavigateIntent('/'),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true):
            const _NavigateIntent('/'),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
            const _NavigateIntent('/recent'),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            const _NavigateIntent('/recent'),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
            const _NavigateIntent('/movies'),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true):
            const _NavigateIntent('/movies'),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
            const _NavigateIntent('/tv'),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true):
            const _NavigateIntent('/tv'),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            const _BackIntent(),
        const SingleActivator(LogicalKeyboardKey.f11):
            const _ToggleFullScreenIntent(),
        const SingleActivator(
          LogicalKeyboardKey.keyF,
          meta: true,
          control: true,
        ): const _ToggleFullScreenIntent(),
        const SingleActivator(LogicalKeyboardKey.keyM, meta: true):
            const _MinimizeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (_) {
              GlobalSearch.show(context);
              return null;
            },
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              context.go('/config');
              return null;
            },
          ),
          _NavigateIntent: CallbackAction<_NavigateIntent>(
            onInvoke: (intent) {
              context.go(intent.location);
              return null;
            },
          ),
          _BackIntent: CallbackAction<_BackIntent>(
            onInvoke: (_) {
              if (context.canPop()) context.pop();
              return null;
            },
          ),
          _ToggleFullScreenIntent: CallbackAction<_ToggleFullScreenIntent>(
            onInvoke: (_) {
              DesktopWindow.toggleFullScreen();
              return null;
            },
          ),
          _MinimizeIntent: CallbackAction<_MinimizeIntent>(
            onInvoke: (_) {
              DesktopWindow.minimize();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useSidebar = constraints.maxWidth >= 840;
              final favoritesSelected = _location(
                context,
              ).startsWith('/favorites');
              final sourcesSelected = _location(context).startsWith('/sources');

              return Scaffold(
                extendBody: !useSidebar && PlatformCapabilities.isIOS,
                backgroundColor: FilmlyPalette.background,
                body: useSidebar
                    ? Stack(
                        children: [
                          Row(
                            children: [
                              _Sidebar(
                                selectedIndex: selected,
                                settingsSelected: settingsSelected,
                                onTapItem: (i) =>
                                    context.go(AppShell._navItems[i].path),
                                onTapSettings: () => context.go('/config'),
                                onTapFavorites: () => context.go('/favorites'),
                                onTapSources: () => context.go('/sources'),
                                favoritesSelected: favoritesSelected,
                                sourcesSelected: sourcesSelected,
                              ),
                              const VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: FilmlyPalette.divider,
                              ),
                              Expanded(child: widget.child),
                            ],
                          ),
                          if (PlatformCapabilities.isMacOS)
                            const Positioned(
                              top: 0,
                              left: 76,
                              right: 0,
                              height: 30,
                              child: DragToMoveArea(child: SizedBox.expand()),
                            ),
                          if (PlatformCapabilities.isWindows)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: kWindowCaptionHeight,
                              child: WindowCaption(
                                brightness: Brightness.light,
                                title: Text('Open Filmly'),
                              ),
                            ),
                        ],
                      )
                    : widget.child,
                bottomNavigationBar: useSidebar
                    ? null
                    : _MobileNavigation(
                        selectedIndex: selected,
                        moreSelected:
                            selected > 3 ||
                            settingsSelected ||
                            favoritesSelected ||
                            sourcesSelected,
                        onNavigate: (path) => context.go(path),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatefulWidget {
  const _MobileNavigation({
    required this.selectedIndex,
    required this.moreSelected,
    required this.onNavigate,
  });

  final int selectedIndex;
  final bool moreSelected;
  final ValueChanged<String> onNavigate;

  @override
  State<_MobileNavigation> createState() => _MobileNavigationState();
}

class _MobileNavigationState extends State<_MobileNavigation> {
  int get _current => widget.moreSelected
      ? 4
      : widget.selectedIndex < 0
      ? 0
      : widget.selectedIndex > 3
      ? 3
      : widget.selectedIndex;

  void _select(int index, {bool fromDrag = false}) {
    if (index < 4) {
      widget.onNavigate(AppShell._navItems[index].path);
    } else if (!fromDrag) {
      _showMore(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformCapabilities.isIOS) {
      return _buildIOSNavigation(context);
    }
    return NavigationBar(
      height: 68,
      selectedIndex: _current,
      onDestinationSelected: (index) {
        _select(index);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: '首页'),
        NavigationDestination(icon: Icon(Icons.history_rounded), label: '最近'),
        NavigationDestination(icon: Icon(Icons.movie_rounded), label: '电影'),
        NavigationDestination(icon: Icon(Icons.tv_rounded), label: '电视剧'),
        NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: '更多',
        ),
      ],
    );
  }

  Widget _buildIOSNavigation(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? 2 : 8),
      child: CNTabBar(
        height: 78,
        shrinkCentered: false,
        items: const [
          CNTabBarItem(label: '首页', icon: CNSymbol('house.fill')),
          CNTabBarItem(label: '最近', icon: CNSymbol('clock.fill')),
          CNTabBarItem(label: '电影', icon: CNSymbol('film.fill')),
          CNTabBarItem(label: '电视剧', icon: CNSymbol('tv.fill')),
          CNTabBarItem(label: '更多', icon: CNSymbol('ellipsis')),
        ],
        currentIndex: _current,
        onTap: (index) {
          HapticFeedback.selectionClick();
          _select(index);
        },
      ),
    );
  }

  Future<void> _showMore(BuildContext context) {
    if (PlatformCapabilities.isIOS) {
      return showCupertinoModalPopup<void>(
        context: context,
        builder: (popupContext) => CupertinoActionSheet(
          title: const Text('更多媒体库'),
          message: const Text('选择要打开的内容'),
          actions: [
            for (final item in AppShell._navItems.skip(4))
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(popupContext);
                  widget.onNavigate(item.path);
                },
                child: Text(item.label),
              ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(popupContext);
                widget.onNavigate('/favorites');
              },
              child: const Text('收藏'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(popupContext);
                widget.onNavigate('/sources');
              },
              child: const Text('来源'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(popupContext);
                widget.onNavigate('/config');
              },
              child: const Text('设置'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(popupContext),
            child: const Text('取消'),
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            for (final item in AppShell._navItems.skip(4))
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate(item.path);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.favorite_rounded),
              title: const Text('收藏'),
              onTap: () {
                Navigator.pop(context);
                widget.onNavigate('/favorites');
              },
            ),
            ListTile(
              leading: const Icon(Icons.dns_rounded),
              title: const Text('来源'),
              onTap: () {
                Navigator.pop(context);
                widget.onNavigate('/sources');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context);
                widget.onNavigate('/config');
              },
            ),
          ],
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
    required this.onTapFavorites,
    required this.onTapSources,
    required this.favoritesSelected,
    required this.sourcesSelected,
  });

  final int selectedIndex;
  final bool settingsSelected;
  final bool favoritesSelected;
  final bool sourcesSelected;
  final ValueChanged<int> onTapItem;
  final VoidCallback onTapSettings;
  final VoidCallback onTapFavorites;
  final VoidCallback onTapSources;

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return Container(
      width: 212,
      color: FilmlyPalette.sidebar,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, isMac ? 38 : 16, 12, 14),
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
                      selected:
                          i == selectedIndex &&
                          !settingsSelected &&
                          !favoritesSelected &&
                          !sourcesSelected,
                      onTap: () => onTapItem(i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: FilmlyPalette.divider),
              const SizedBox(height: 10),
              // Account row + quick actions (favorites / sources / settings)
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
                        'xiaoyu',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: FilmlyPalette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _SidebarIconButton(
                      key: const Key('sidebar_/favorites'),
                      icon: Icons.favorite_rounded,
                      selected: favoritesSelected,
                      tooltip: '收藏',
                      onTap: onTapFavorites,
                    ),
                    _SidebarIconButton(
                      key: const Key('sidebar_/sources'),
                      icon: Icons.dns_rounded,
                      selected: sourcesSelected,
                      tooltip: '来源',
                      onTap: onTapSources,
                    ),
                    _SidebarIconButton(
                      key: const Key('sidebar_/config'),
                      icon: Icons.settings_rounded,
                      selected: settingsSelected,
                      tooltip: '设置',
                      onTap: onTapSettings,
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

    return Semantics(
      label: widget.label,
      button: true,
      selected: widget.selected,
      child: MouseRegion(
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
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: selected
                ? FilmlyPalette.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: selected
                ? FilmlyPalette.accent
                : FilmlyPalette.textSecondary,
            size: 18,
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

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _NavigateIntent extends Intent {
  const _NavigateIntent(this.location);
  final String location;
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _ToggleFullScreenIntent extends Intent {
  const _ToggleFullScreenIntent();
}

class _MinimizeIntent extends Intent {
  const _MinimizeIntent();
}
