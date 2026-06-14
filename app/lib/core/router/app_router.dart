import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/media.dart';
import '../../features/config/config_page.dart';
import '../../features/config/emby_browser_page.dart';
import '../../features/config/smb_browser_page.dart';
import '../../features/config/webdav_browser_page.dart';
import '../../features/home/home_page.dart';
import '../../features/library/favorites_page.dart';
import '../../features/library/library_page.dart';
import '../../features/library/media_detail_page.dart';
import '../../features/player/player_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/sources/local_folders_page.dart';
import '../../features/sources/sources_page.dart';

/// Global navigator key so routes outside the shell (e.g. player) can push
/// on top of the entire viewport.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Location for a media detail page. Ids are raw file paths / URIs, so they
/// must be query-encoded — never interpolate an id into the path.
String mediaDetailLocation(String mediaId) =>
    '/media?id=${Uri.encodeQueryComponent(mediaId)}';

/// Wraps [child] in a soft fade + subtle upward slide transition, shared by
/// all in-shell routes so the content area cross-fades between pages.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// Builds the application router. The [initialLocation] override is kept
/// injectable so widget tests can boot directly into a specific route.
GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/player',
      builder: (context, state) {
        final args = state.extra as PlayerArgs;
        return PlayerPage(args: args);
      },
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => _fadePage(state, const HomePage()),
        ),
        GoRoute(
          path: '/recent',
          pageBuilder: (context, state) =>
              _fadePage(state, const HomePage(initialTab: HomeTab.recent)),
        ),
        GoRoute(
          path: '/movies',
          pageBuilder: (context, state) =>
              _fadePage(state, const LibraryPage(type: MediaType.movie)),
        ),
        GoRoute(
          path: '/tv',
          pageBuilder: (context, state) =>
              _fadePage(state, const LibraryPage(type: MediaType.tv)),
        ),
        GoRoute(
          path: '/favorites',
          pageBuilder: (context, state) =>
              _fadePage(state, const FavoritesPage()),
        ),
        GoRoute(
          path: '/anime',
          pageBuilder: (context, state) => _fadePage(
            state,
            const LibraryPage(
              type: null,
              customTitle: '动漫',
              genreTerms: ['动漫', '动画', 'animation', 'anime'],
            ),
          ),
        ),
        GoRoute(
          path: '/variety',
          pageBuilder: (context, state) => _fadePage(
            state,
            const LibraryPage(
              type: null,
              customTitle: '综艺',
              genreTerms: [
                '综艺',
                '真人秀',
                '脱口秀',
                'reality',
                'talk show',
                'variety',
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/concert',
          pageBuilder: (context, state) => _fadePage(
            state,
            const LibraryPage(
              type: null,
              customTitle: '演唱会',
              genreTerms: ['演唱会', '音乐', 'concert', 'music'],
            ),
          ),
        ),
        GoRoute(
          path: '/documentary',
          pageBuilder: (context, state) => _fadePage(
            state,
            const LibraryPage(
              type: null,
              customTitle: '纪录片',
              genreTerms: ['纪录', '纪录片', 'documentary'],
            ),
          ),
        ),
        GoRoute(
          path: '/other',
          pageBuilder: (context, state) => _fadePage(
            state,
            const LibraryPage(type: MediaType.unknown, customTitle: '其他'),
          ),
        ),
        GoRoute(
          path: '/unmatched',
          pageBuilder: (context, state) =>
              _fadePage(state, const LibraryPage(type: MediaType.unknown)),
        ),
        GoRoute(
          // Media ids are raw file paths / URIs (slashes, spaces, CJK), so
          // they travel as a query parameter — a path segment would break
          // route matching (GoException: no routes for location).
          path: '/media',
          pageBuilder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return _fadePage(state, MediaDetailPage(id: id));
          },
        ),
        GoRoute(
          path: '/sources',
          pageBuilder: (context, state) =>
              _fadePage(state, const SourcesPage()),
        ),
        GoRoute(
          path: '/sources/local',
          pageBuilder: (context, state) =>
              _fadePage(state, const LocalFoldersPage()),
        ),
        GoRoute(
          path: '/smb',
          pageBuilder: (context, state) =>
              _fadePage(state, const SmbBrowserPage()),
        ),
        GoRoute(
          path: '/webdav',
          pageBuilder: (context, state) =>
              _fadePage(state, const WebDavBrowserPage()),
        ),
        GoRoute(
          path: '/emby',
          pageBuilder: (context, state) =>
              _fadePage(state, const EmbyBrowserPage()),
        ),
        GoRoute(
          path: '/config',
          pageBuilder: (context, state) => _fadePage(state, const ConfigPage()),
        ),
      ],
    ),
  ],
);

final appRouter = createAppRouter();
