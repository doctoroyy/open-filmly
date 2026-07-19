import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/image/filmly_image_cache.dart';
import '../../core/platform/open_player.dart';
import '../../core/router/app_router.dart';

import '../../data/models/continue_watching_item.dart';
import '../../data/models/media.dart';
import '../../providers/data_providers.dart';
import '../../providers/smb_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../widgets/global_search.dart';
import '../../widgets/media_poster_card.dart';
import '../player/player_page.dart';

/// Home dashboard, modeled on NetEase 爆米花: a top bar plus horizontally
/// scrolling shelves (最近观看 landscape, then 收藏 / 电影 / 电视剧 posters).
enum HomeTab { overview, movies, tv, recent }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialTab = HomeTab.overview});

  /// Kept for route compatibility; the NetEase-style home is a single scroll
  /// so tabs are no longer used for layout.
  final HomeTab initialTab;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _refreshing = false;

  Future<void> _resumeMedia(Media media, {Duration? startAt}) async {
    try {
      await withPlayerLaunchLoading(context, () async {
        final source = await ref
            .read(playbackSourceResolverProvider)
            .resolve(media);
        if (!mounted) return;
        await openPlayer(
          context,
          PlayerArgs(
            uri: source.uri,
            title: media.title,
            mediaId: media.id,
            startAt: startAt,
            httpHeaders: source.httpHeaders,
            subtitles: source.subtitles,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('播放失败：$error')));
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final config = await ref.read(configProvider.future);
      final result = await ref.read(libraryAutoScanProvider).run(config);
      invalidateLibraryViews(ref);
      if (!mounted) return;
      final parts = <String>[
        if (result.importedItems > 0) '新增 ${result.importedItems}',
        if (result.enrichedItems > 0) '匹配 ${result.enrichedItems}',
        if (result.retitledItems > 0) '整理 ${result.retitledItems}',
      ];
      final message = parts.isEmpty
          ? (config.tmdbApiKey.isEmpty
                ? '已刷新（未配置 TMDB Key，无法自动匹配海报）'
                : '已刷新，暂无需要匹配的条目')
          : '刷新完成：${parts.join(' · ')}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刷新失败：$e')));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(libraryCountsProvider).asData?.value ?? const {};
    final continueItems =
        ref.watch(continueWatchingProvider).asData?.value ?? const [];
    final favorites = ref.watch(favoritesProvider).asData?.value ?? const [];
    final movies = ref.watch(featuredMoviesProvider).asData?.value ?? const [];
    final tv = ref.watch(featuredTvProvider).asData?.value ?? const [];
    final recent = ref.watch(recentMediaProvider).asData?.value ?? const [];
    final total = counts.values.fold<int>(0, (s, v) => s + v);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(
            refreshing: _refreshing,
            onSearch: () => GlobalSearch.show(context),
            onRefresh: _refresh,
            onSources: () => context.go('/sources'),
            onSettings: () => context.go('/config'),
          ),
          Expanded(
            child: total == 0
                ? _emptyLibrary(context)
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 36),
                    children: [
                      if (continueItems.isNotEmpty)
                        _ContinueShelf(
                          items: continueItems,
                          onTap: (item) => _resumeMedia(
                            item.media,
                            startAt: item.progress.position,
                          ),
                          onMore: () => context.go('/recent'),
                        ),
                      if (favorites.isNotEmpty)
                        _PosterShelf(
                          title: '收藏',
                          items: favorites,
                          moreLabel: '全部 ${favorites.length}',
                          onMore: () => context.push('/favorites'),
                        ),
                      if (movies.isNotEmpty)
                        _PosterShelf(
                          title: '电影',
                          items: movies,
                          moreLabel:
                              '全部 ${counts[MediaType.movie] ?? movies.length}',
                          onMore: () => context.go('/movies'),
                        ),
                      if (tv.isNotEmpty)
                        _PosterShelf(
                          title: '电视剧',
                          items: tv,
                          moreLabel: '全部 ${counts[MediaType.tv] ?? tv.length}',
                          onMore: () => context.go('/tv'),
                        ),
                      if (continueItems.isEmpty &&
                          movies.isEmpty &&
                          tv.isEmpty &&
                          recent.isNotEmpty)
                        _PosterShelf(
                          title: '最近添加',
                          items: recent,
                          moreLabel: '',
                          onMore: null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyLibrary(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: FilmlyPalette.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 36,
              color: FilmlyPalette.textMuted,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '开始构建你的影视库',
            style: TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '添加影片来源后，系统会自动扫描、整理并生成海报墙。',
            style: TextStyle(color: FilmlyPalette.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          FilmlyGlassButton(
            label: '添加来源',
            icon: Icons.add_rounded,
            accent: true,
            onTap: () => context.go('/sources'),
          ),
        ],
      ),
    );
  }
}

/// NetEase-style content header: page title on the left, circular actions on
/// the right (search / refresh / add source).
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.refreshing,
    required this.onSearch,
    required this.onRefresh,
    required this.onSources,
    required this.onSettings,
  });

  final bool refreshing;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback onSources;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final isIOS = Platform.isIOS;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isIOS ? 20 : 28,
        isMac ? 34 : (isIOS ? 14 : 18),
        isIOS ? 18 : 24,
        10,
      ),
      child: Row(
        children: [
          Text(
            '首页',
            style: TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: isIOS ? 28 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: isIOS ? -0.8 : -0.4,
            ),
          ),
          const Spacer(),
          _circleButton(
            context,
            Icons.search_rounded,
            onSearch,
            tooltip: '搜索 (⌘F)',
            key: const Key('home_search_button'),
          ),
          const SizedBox(width: 10),
          _circleButton(
            context,
            Icons.refresh_rounded,
            refreshing ? null : onRefresh,
            tooltip: '刷新媒体库',
            spinning: refreshing,
            key: const Key('home_refresh_button'),
          ),
          const SizedBox(width: 10),
          _circleButton(
            context,
            Icons.add_rounded,
            onSources,
            tooltip: '添加来源',
            key: const Key('home_add_source_button'),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap, {
    required String tooltip,
    bool spinning = false,
    Key? key,
  }) {
    if (Platform.isIOS) {
      return Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: 38,
          child: spinning
              ? const Center(child: CupertinoActivityIndicator(radius: 9))
              : CNButton.icon(
                  key: key,
                  customIcon: icon,
                  onPressed: onTap,
                  enabled: onTap != null,
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    width: 38,
                    minHeight: 38,
                    padding: EdgeInsets.zero,
                    borderRadius: 19,
                    customIconSize: 18,
                    glassEffectUnionId: 'home-toolbar',
                  ),
                ),
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: FilmlyPalette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: FilmlyPalette.divider),
          ),
          child: spinning
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: FilmlyPalette.textSecondary, size: 19),
        ),
      ),
    );
  }
}

/// A titled shelf header with an optional "全部 N >" action.
class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({required this.title, this.moreLabel, this.onMore});

  final String title;
  final String? moreLabel;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: Row(
                children: [
                  Text(
                    moreLabel ?? '全部',
                    style: const TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: FilmlyPalette.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal shelf of 16:9 "continue watching" cards with progress + time.
class _ContinueShelf extends StatelessWidget {
  const _ContinueShelf({
    required this.items,
    required this.onTap,
    required this.onMore,
  });

  final List<ContinueWatchingItem> items;
  final void Function(ContinueWatchingItem) onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfHeader(
          title: '最近播放',
          moreLabel: '全部 ${items.length}',
          onMore: onMore,
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) => _ContinueCard(
              item: items[index],
              onTap: () => onTap(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.item, required this.onTap});

  final ContinueWatchingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final media = item.media;
    final fraction = item.progress.fractionWatched.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 278,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _thumb(media),
                    Positioned(
                      right: 8,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.progress.progressLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 3,
                        color: Colors.white.withValues(alpha: 0.22),
                        child: FractionallySizedBox(
                          widthFactor: fraction,
                          alignment: Alignment.centerLeft,
                          child: Container(color: FilmlyPalette.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              media.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(Media media) {
    return _image(
      media.backdropPath,
      media,
      fallback: () => _image(media.posterPath, media),
    );
  }

  Widget _image(String? path, Media media, {Widget Function()? fallback}) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return fallback?.call() ?? _placeholder(media);

    final networkUrl = FilmlyImageCache.networkUrl(
      value,
      size: TmdbImageSize.w780,
    );
    if (networkUrl != null) {
      return FilmlyNetworkImage(
        imageUrl: networkUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => _placeholder(media),
        errorWidget: (_, _, _) => fallback?.call() ?? _placeholder(media),
      );
    }

    final file = File(value);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback?.call() ?? _placeholder(media),
      );
    }

    return fallback?.call() ?? _placeholder(media);
  }

  Widget _placeholder(Media media) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE4E7EB), Color(0xFFEDF0F3)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        media.type == MediaType.tv ? Icons.tv_rounded : Icons.movie_rounded,
        color: FilmlyPalette.textMuted,
        size: 34,
      ),
    );
  }
}

/// Horizontal shelf of 2:3 poster cards.
class _PosterShelf extends StatelessWidget {
  const _PosterShelf({
    required this.title,
    required this.items,
    required this.moreLabel,
    required this.onMore,
  });

  final String title;
  final List<Media> items;
  final String moreLabel;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfHeader(
          title: title,
          moreLabel: moreLabel.isEmpty ? null : moreLabel,
          onMore: onMore,
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final media = items[index];
              return SizedBox(
                width: 132,
                child: MediaPosterCard(
                  media: media,
                  onTap: () => context.push(mediaDetailLocation(media.id)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
