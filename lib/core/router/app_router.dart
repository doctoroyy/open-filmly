import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/library_shelf.dart';
import '../../data/models/media.dart';
import '../../data/models/resource_source.dart';
import '../../features/config/config_page.dart';
import '../../features/config/emby_browser_page.dart';
import '../../features/config/smb_browser_page.dart';
import '../../features/config/webdav_browser_page.dart';
import '../../features/home/home_page.dart';
import '../../features/home/me_page.dart';
import '../../features/home/search_page.dart';
import '../../features/intelligence/ask_filmly_page.dart';
import '../../features/intelligence/media_agent_page.dart';
import '../../features/intelligence/personal_memory_page.dart';
import '../../features/library/favorites_page.dart';
import '../../features/library/library_page.dart';
import '../../features/library/media_detail_page.dart';
import '../../features/player/player_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/sources/local_folders_page.dart';
import '../../features/sources/resource_source_pages.dart';
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

Page<void> _tabPage(GoRouterState state, Widget child) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }
  return _fadePage(state, child);
}

/// Builds the application router. The [initialLocation] override is kept
/// injectable so widget tests can boot directly into a specific route.
GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [CNTabBarRouteObserver()],
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
          pageBuilder: (context, state) => _tabPage(state, const HomePage()),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => _tabPage(state, const SearchPage()),
        ),
        GoRoute(
          path: '/ask',
          pageBuilder: (context, state) => _fadePage(
            state,
            AskFilmlyPage(initialQuery: state.uri.queryParameters['q']),
          ),
        ),
        GoRoute(
          path: '/me',
          pageBuilder: (context, state) => _tabPage(state, const MePage()),
        ),
        GoRoute(
          path: '/recent',
          pageBuilder: (context, state) =>
              _tabPage(state, const HomePage(initialTab: HomeTab.recent)),
        ),
        GoRoute(
          path: '/movies',
          pageBuilder: (context, state) =>
              _tabPage(state, const LibraryPage(shelf: LibraryShelf.movie)),
        ),
        GoRoute(
          path: '/tv',
          pageBuilder: (context, state) =>
              _tabPage(state, const LibraryPage(shelf: LibraryShelf.tv)),
        ),
        GoRoute(
          path: '/favorites',
          pageBuilder: (context, state) =>
              _fadePage(state, const FavoritesPage()),
        ),
        GoRoute(
          path: '/anime',
          pageBuilder: (context, state) =>
              _tabPage(state, const LibraryPage(shelf: LibraryShelf.anime)),
        ),
        GoRoute(
          path: '/variety',
          pageBuilder: (context, state) =>
              _tabPage(state, const LibraryPage(shelf: LibraryShelf.variety)),
        ),
        GoRoute(
          path: '/concert',
          pageBuilder: (context, state) =>
              _tabPage(state, const LibraryPage(shelf: LibraryShelf.concert)),
        ),
        GoRoute(
          path: '/documentary',
          pageBuilder: (context, state) => _tabPage(
            state,
            const LibraryPage(shelf: LibraryShelf.documentary),
          ),
        ),
        GoRoute(
          path: '/other',
          pageBuilder: (context, state) =>
              _tabPage(state, const LibraryPage(shelf: LibraryShelf.other)),
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
          path: '/sources/add',
          pageBuilder: (context, state) =>
              _fadePage(state, const AddResourceSourcePage()),
        ),
        GoRoute(
          path: '/sources/edit',
          pageBuilder: (context, state) {
            final typeName = state.uri.queryParameters['type'] ?? 'webdav';
            final type = ResourceSourceType.values.firstWhere(
              (value) => value.name == typeName,
              orElse: () => ResourceSourceType.webdav,
            );
            return _fadePage(
              state,
              ResourceSourceEditorPage(
                type: type,
                sourceId: state.uri.queryParameters['sourceId'],
              ),
            );
          },
        ),
        GoRoute(
          path: '/smb',
          pageBuilder: (context, state) => _fadePage(
            state,
            SmbBrowserPage(sourceId: state.uri.queryParameters['sourceId']),
          ),
        ),
        GoRoute(
          path: '/webdav',
          pageBuilder: (context, state) => _fadePage(
            state,
            WebDavBrowserPage(sourceId: state.uri.queryParameters['sourceId']),
          ),
        ),
        GoRoute(
          path: '/emby',
          pageBuilder: (context, state) => _fadePage(
            state,
            EmbyBrowserPage(sourceId: state.uri.queryParameters['sourceId']),
          ),
        ),
        GoRoute(
          path: '/config',
          pageBuilder: (context, state) => _fadePage(state, const ConfigPage()),
        ),
        GoRoute(
          path: '/memory',
          pageBuilder: (context, state) =>
              _fadePage(state, const PersonalMemoryPage()),
        ),
        GoRoute(
          path: '/agent',
          pageBuilder: (context, state) => _fadePage(
            state,
            MediaAgentPage(initialPrompt: state.uri.queryParameters['prompt']),
          ),
        ),
      ],
    ),
  ],
);

final appRouter = createAppRouter();
