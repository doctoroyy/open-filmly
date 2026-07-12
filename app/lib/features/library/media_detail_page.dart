import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/rating_formatter.dart';
import '../../data/models/episode.dart';
import '../../data/models/media.dart';
import '../../data/models/playback_progress.dart';
import '../../providers/data_providers.dart';
import '../../providers/smb_providers.dart';
import '../../services/library/media_library_entry_factory.dart';
import '../../services/metadata/tmdb_metadata_service.dart';
import '../../widgets/filmly_design.dart';
import '../../widgets/filmly_error_state.dart';
import '../player/player_page.dart';

/// Media detail route for a single library item.
class MediaDetailPage extends ConsumerWidget {
  const MediaDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaByIdProvider(id));
    final progress = ref
        .watch(playbackProgressByMediaIdProvider(id))
        .asData
        ?.value;

    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => FilmlyErrorState(
            message: '加载详情失败：$e',
            onRetry: () => ref.invalidate(mediaByIdProvider(id)),
          ),
          data: (media) {
            if (media == null) {
              return _notFound(context);
            }
            return _content(context, ref, media, progress);
          },
        ),
      ),
    );
  }

  Widget _notFound(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilmlyInlineHeader(
            leading: FilmlyIconButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            title: '媒体详情',
          ),
          const Expanded(
            child: Center(
              child: Text(
                '未找到该媒体',
                style: TextStyle(color: FilmlyPalette.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    Media media,
    PlaybackProgress? progress,
  ) {
    final source = (media.fullPath != null && media.fullPath!.isNotEmpty)
        ? media.fullPath!
        : media.path;
    final resumeProgress = progress?.hasResumePoint == true ? progress : null;

    final backdrop = media.backdropPath?.isNotEmpty == true
        ? media.backdropPath!
        : media.posterPath;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(
          media: media,
          backdrop: backdrop,
          resumeProgress: resumeProgress,
          completed: progress?.completed == true,
          progressLabel: progress?.progressLabel,
          onBack: () => context.canPop() ? context.pop() : context.go('/'),
          onToggleFavorite: () => _toggleFavorite(ref, media),
          onPlay: source.isEmpty
              ? null
              : () => _playMedia(
                  context,
                  ref,
                  media,
                  startAt: resumeProgress?.position,
                ),
          onRestart: source.isEmpty
              ? null
              : () => _playMedia(context, ref, media),
          onReMatch: () => _showReMatchDialog(context, ref, media),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (media.type == MediaType.tv) ...[
                _episodesSection(context, ref, media),
                const SizedBox(height: 28),
              ],
              _CastRow(mediaId: media.id),
              _infoBlock(context, '片源路径', source),
              if (media.fileHash != null && media.fileHash!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _infoBlock(context, '文件哈希', media.fileHash!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _episodesSection(BuildContext context, WidgetRef ref, Media media) {
    final seasonsAsync = ref.watch(episodesByShowProvider(media.id));

    return seasonsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FilmlyErrorState(
        message: '加载剧集列表失败：$e',
        compact: true,
        onRetry: () => ref.invalidate(episodesByShowProvider(media.id)),
      ),
      data: (seasons) {
        if (seasons.isEmpty) {
          return FilmlyGlassPanel(
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.all(20),
            child: const Text(
              '暂无剧集数据。扫描包含 S01E01 等命名的文件后，剧集将自动出现在这里。',
              style: TextStyle(
                color: FilmlyPalette.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          );
        }
        return _SeasonEpisodeBrowser(
          seasons: seasons,
          show: media,
          onPlay: (episode) => _playEpisode(context, ref, episode, media),
          onShowDetails: (episode) =>
              _showEpisodeDetails(context, episode, media),
        );
      },
    );
  }

  void _showEpisodeDetails(BuildContext context, Episode episode, Media show) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FilmlyPalette.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _EpisodeDetailsSheet(episode: episode, show: show),
    );
  }

  Future<void> _toggleFavorite(WidgetRef ref, Media media) async {
    await ref
        .read(mediaRepositoryProvider)
        .setFavorite(media.id, !media.isFavorite);
    ref.invalidate(mediaByIdProvider(media.id));
    ref.invalidate(favoritesProvider);
  }

  Future<void> _playEpisode(
    BuildContext context,
    WidgetRef ref,
    Episode episode,
    Media show,
  ) async {
    try {
      // Episodes inherit the show's source; resolve to a playable URI so that
      // SMB/WebDAV episodes stream correctly rather than opening a raw id URI.
      final playable = MediaLibraryEntryFactory.episodePlayableMedia(
        episode,
        show,
      );
      final source = await ref
          .read(playbackSourceResolverProvider)
          .resolve(playable);
      final progress = await ref
          .read(playbackProgressRepositoryProvider)
          .getByMediaId(episode.id);
      final startAt = progress != null && progress.hasResumePoint
          ? progress.position
          : null;
      if (!context.mounted) return;
      context.push(
        '/player',
        extra: PlayerArgs(
          uri: source.uri,
          title: '${show.title} - ${episode.displayLabel}',
          mediaId: episode.id,
          startAt: startAt,
          httpHeaders: source.httpHeaders,
          subtitles: source.subtitles,
          showId: show.id,
          showTitle: show.title,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('播放失败：$e')));
    }
  }

  Future<void> _playMedia(
    BuildContext context,
    WidgetRef ref,
    Media media, {
    Duration? startAt,
  }) async {
    try {
      final source = await ref
          .read(playbackSourceResolverProvider)
          .resolve(media);
      if (!context.mounted) return;
      context.push(
        '/player',
        extra: PlayerArgs(
          uri: source.uri,
          title: media.title,
          mediaId: media.id,
          startAt: startAt,
          httpHeaders: source.httpHeaders,
          subtitles: source.subtitles,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('播放失败：$e')));
    }
  }

  Widget _infoBlock(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FilmlyPalette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: const TextStyle(
            color: FilmlyPalette.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  void _showReMatchDialog(BuildContext context, WidgetRef ref, Media media) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => _ReMatchDialog(media: media),
    );
  }
}

/// NetEase-style season tabs with one horizontal row for the selected season.
class _SeasonEpisodeBrowser extends StatefulWidget {
  const _SeasonEpisodeBrowser({
    required this.seasons,
    required this.show,
    required this.onPlay,
    required this.onShowDetails,
  });

  final List<Season> seasons;
  final Media show;
  final ValueChanged<Episode> onPlay;
  final ValueChanged<Episode> onShowDetails;

  @override
  State<_SeasonEpisodeBrowser> createState() => _SeasonEpisodeBrowserState();
}

class _SeasonEpisodeBrowserState extends State<_SeasonEpisodeBrowser> {
  late int _selectedSeason;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.seasons.first.number;
  }

  @override
  void didUpdateWidget(covariant _SeasonEpisodeBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.seasons.any((season) => season.number == _selectedSeason)) {
      _selectedSeason = widget.seasons.first.number;
    }
  }

  @override
  Widget build(BuildContext context) {
    final season = widget.seasons.firstWhere(
      (item) => item.number == _selectedSeason,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.seasons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 32),
            itemBuilder: (context, index) {
              final item = widget.seasons[index];
              final selected = item.number == _selectedSeason;
              return GestureDetector(
                key: Key('season_tab_${item.number}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedSeason = item.number),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.only(top: 4, bottom: 9),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected
                            ? FilmlyPalette.textPrimary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    '第${item.number}季',
                    style: TextStyle(
                      color: selected
                          ? FilmlyPalette.textPrimary
                          : FilmlyPalette.textMuted,
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: SizedBox(
            key: ValueKey(_selectedSeason),
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: season.episodes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final episode = season.episodes[index];
                return _EpisodeCard(
                  key: Key('episode_card_${episode.id}'),
                  episode: episode,
                  show: widget.show,
                  onPlay: () => widget.onPlay(episode),
                  onShowDetails: () => widget.onShowDetails(episode),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EpisodeCard extends ConsumerStatefulWidget {
  const _EpisodeCard({
    super.key,
    required this.episode,
    required this.show,
    required this.onPlay,
    required this.onShowDetails,
  });

  final Episode episode;
  final Media show;
  final VoidCallback onPlay;
  final VoidCallback onShowDetails;

  @override
  ConsumerState<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends ConsumerState<_EpisodeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final details = ref
        .watch(
          episodeDetailsProvider((
            showId: widget.show.id,
            season: widget.episode.seasonNumber,
            episode: widget.episode.episodeNumber,
          )),
        )
        .asData
        ?.value;
    final title = details?.name.isNotEmpty == true
        ? details!.name
        : (widget.episode.title.isEmpty
              ? '第 ${widget.episode.episodeNumber} 集'
              : widget.episode.title);

    return SizedBox(
      width: 224,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPlay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _still(details?.stillUrl),
                      AnimatedOpacity(
                        opacity: _hovered ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.24),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: GestureDetector(
                            onTap: widget.onShowDetails,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '${widget.episode.episodeNumber}. $title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FilmlyPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _still(String? url) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, _) => _stillPlaceholder(),
        errorWidget: (_, _, _) => _stillPlaceholder(),
      );
    }
    return _stillPlaceholder();
  }

  Widget _stillPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDE2E7), Color(0xFFEEF1F3)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'E${widget.episode.episodeNumber.toString().padLeft(2, '0')}',
        style: const TextStyle(
          color: FilmlyPalette.textMuted,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Bottom sheet showing a single episode's TMDB metadata (still, overview,
/// air date), fetched on demand. Falls back gracefully when unavailable.
class _EpisodeDetailsSheet extends ConsumerWidget {
  const _EpisodeDetailsSheet({required this.episode, required this.show});

  final Episode episode;
  final Media show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(
      episodeDetailsProvider((
        showId: show.id,
        season: episode.seasonNumber,
        episode: episode.episodeNumber,
      )),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'S${episode.seasonNumber.toString().padLeft(2, '0')}'
              'E${episode.episodeNumber.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            detailsAsync.when(
              loading: () => _body(
                title: episode.title.isEmpty
                    ? episode.displayLabel
                    : episode.title,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              error: (_, _) => _body(
                title: episode.title.isEmpty
                    ? episode.displayLabel
                    : episode.title,
                child: const _Hint('暂时无法获取本集详情'),
              ),
              data: (details) {
                final title = (details?.name.isNotEmpty ?? false)
                    ? details!.name
                    : (episode.title.isEmpty
                          ? episode.displayLabel
                          : episode.title);
                return _body(
                  title: title,
                  still: details?.stillUrl,
                  airDate: details?.airDate,
                  rating: details?.rating,
                  overview: details?.overview,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({
    required String title,
    String? still,
    String? airDate,
    String? rating,
    String? overview,
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        if (still != null && still.isNotEmpty) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: still,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    Container(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
          ),
        ],
        if ((airDate != null && airDate.isNotEmpty) ||
            (rating != null && rating.isNotEmpty)) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (airDate != null && airDate.isNotEmpty) ...[
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: FilmlyPalette.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  airDate,
                  style: const TextStyle(
                    color: FilmlyPalette.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              if (rating != null && rating.isNotEmpty) ...[
                const Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: Color(0xFFFFC857),
                ),
                const SizedBox(width: 4),
                Text(
                  formatRating(rating) ?? rating,
                  style: const TextStyle(
                    color: FilmlyPalette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
        if (overview != null && overview.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            overview,
            style: const TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
        ?child,
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        message,
        style: const TextStyle(color: FilmlyPalette.textMuted, fontSize: 14),
      ),
    );
  }
}

/// Full-bleed backdrop hero with overlaid title, meta, actions, and overview —
/// matching NetEase 爆米花's Mac detail layout.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.media,
    required this.backdrop,
    required this.resumeProgress,
    required this.completed,
    required this.progressLabel,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onPlay,
    required this.onRestart,
    required this.onReMatch,
  });

  final Media media;
  final String? backdrop;
  final PlaybackProgress? resumeProgress;
  final bool completed;
  final String? progressLabel;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onPlay;
  final VoidCallback? onRestart;
  final VoidCallback onReMatch;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (media.rating != null && media.rating!.isNotEmpty)
        '★ ${formatRating(media.rating)}',
      if (media.year.isNotEmpty) media.year,
      ...media.genres.take(3),
    ].join('  ·  ');
    final showRestart = resumeProgress != null || completed;

    return SizedBox(
      height: 460,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _background(),
          // Scrim: fade bottom into light gray content background.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(
                    0x1F000000,
                  ), // Very subtle top darkening for status/buttons visibility
                  Color(0x00000000),
                  Color(0x66F3F3F6),
                  Color(0xFFF3F3F6), // Fully dissolves into scaffold background
                ],
                stops: [0, 0.35, 0.72, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  _HeroIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: onBack,
                  ),
                  const Spacer(),
                  _HeroIconButton(
                    key: const Key('detail_re-match_button'),
                    icon: Icons.auto_fix_high_rounded,
                    onTap: onReMatch,
                  ),
                  const SizedBox(width: 12),
                  _HeroIconButton(
                    icon: media.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    onTap: onToggleFavorite,
                    tint: media.isFavorite ? FilmlyPalette.accent : null,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 36,
            right: 36,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  media.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FilmlyPalette.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    meta,
                    style: const TextStyle(
                      color: FilmlyPalette.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    _heroPlayButton(
                      label: resumeProgress != null ? '继续播放' : '播放',
                      filled: true,
                      onTap: onPlay,
                    ),
                    if (showRestart) ...[
                      const SizedBox(width: 12),
                      _heroPlayButton(
                        label: completed ? '重新播放' : '从头播放',
                        filled: false,
                        onTap: onRestart,
                      ),
                    ],
                  ],
                ),
                if (resumeProgress != null && progressLabel != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '上次播放到 $progressLabel',
                    style: const TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (media.overview != null && media.overview!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Text(
                      media.overview!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FilmlyPalette.textSecondary,
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _background() {
    final url = backdrop;
    if (url != null && url.isNotEmpty) {
      final resolved = url.startsWith('/')
          ? 'https://image.tmdb.org/t/p/w1280$url'
          : url;
      if (!resolved.startsWith('http')) return _gradient();
      return CachedNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        placeholder: (_, _) => _gradient(),
        errorWidget: (_, _, _) => _gradient(),
      );
    }
    return _gradient();
  }

  Widget _gradient() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5E9EC), Color(0xFFEFF2F5)],
        ),
      ),
    );
  }

  Widget _heroPlayButton({
    required String label,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: filled
              ? FilmlyPalette.primary.withValues(alpha: enabled ? 1 : 0.4)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: FilmlyPalette.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filled ? Icons.play_arrow_rounded : Icons.restart_alt_rounded,
              size: 20,
              color: filled ? Colors.white : FilmlyPalette.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : FilmlyPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: tint ?? FilmlyPalette.textPrimary, size: 22),
      ),
    );
  }
}

/// Horizontal 相关演员 row of circular avatars + names, NetEase-style.
/// Hidden entirely when there is no cast (no TMDB id / key / results).
class _CastRow extends ConsumerWidget {
  const _CastRow({required this.mediaId});

  final String mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castAsync = ref.watch(castProvider(mediaId));
    final cast = castAsync.asData?.value ?? const [];
    if (cast.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '相关演员',
            style: TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final member = cast[index];
                return SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: member.profileUrl == null
                              ? Container(
                                  color: FilmlyPalette.surfaceStrong,
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: FilmlyPalette.textMuted,
                                    size: 30,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: member.profileUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(
                                    color: FilmlyPalette.surfaceStrong,
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: FilmlyPalette.textMuted,
                                      size: 30,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: FilmlyPalette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (member.character.isNotEmpty)
                        Text(
                          member.character,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: FilmlyPalette.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _FilterType { all, movie, tv }

/// 修正匹配与重新智能识别元数据 Dialog
class _ReMatchDialog extends ConsumerStatefulWidget {
  const _ReMatchDialog({required this.media});

  final Media media;

  @override
  ConsumerState<_ReMatchDialog> createState() => _ReMatchDialogState();
}

class _ReMatchDialogState extends ConsumerState<_ReMatchDialog> {
  late final TextEditingController _searchController;
  late _FilterType _selectedType;
  List<TmdbSearchResult> _results = [];
  bool _isLoading = false;
  bool _isMatching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.media.title);
    _selectedType = switch (widget.media.type) {
      MediaType.movie => _FilterType.movie,
      MediaType.tv => _FilterType.tv,
      _ => _FilterType.all,
    };
    // 首次进入自动加载一次搜索
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final config = ref.read(configProvider).asData?.value;
    if (config == null || config.tmdbApiKey.isEmpty) {
      return;
    }

    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tmdbService = ref.read(tmdbMetadataProvider);
      final searchType = switch (_selectedType) {
        _FilterType.movie => MediaType.movie,
        _FilterType.tv => MediaType.tv,
        _FilterType.all => null,
      };

      final items = await tmdbService.searchAll(
        query,
        config.tmdbApiKey,
        type: searchType,
      );

      if (mounted) {
        setState(() {
          _results = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '搜索出错：$e';
        });
      }
    }
  }

  Future<void> _applyMatch(TmdbSearchResult result) async {
    final config = ref.read(configProvider).asData?.value;
    if (config == null || config.tmdbApiKey.isEmpty) return;

    setState(() {
      _isMatching = true;
    });

    try {
      final syncService = ref.read(libraryMetadataSyncProvider);
      final success = await syncService.manualMatch(
        mediaId: widget.media.id,
        tmdbId: result.id,
        type: result.type,
        apiKey: config.tmdbApiKey,
      );

      if (mounted) {
        if (success) {
          // 重新拉取状态以驱动界面刷新
          ref.invalidate(mediaByIdProvider(widget.media.id));
          ref.invalidate(episodesByShowProvider(widget.media.id));
          ref.invalidate(castProvider(widget.media.id));
          invalidateLibraryViews(ref);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已成功重新匹配为《${result.title}》'),
              backgroundColor: FilmlyPalette.accent,
            ),
          );
          Navigator.of(context).pop();
        } else {
          setState(() {
            _isMatching = false;
            _errorMessage = '匹配失败，无法获取影片详情。';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMatching = false;
          _errorMessage = '匹配过程发生异常：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider).asData?.value;
    final hasApiKey = config != null && config.tmdbApiKey.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FilmlyGlassPanel(
        width: 620,
        height: 540,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部
                Row(
                  children: [
                    const Icon(
                      Icons.auto_fix_high_rounded,
                      color: FilmlyPalette.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '修正影片匹配',
                      style: TextStyle(
                        color: FilmlyPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: FilmlyPalette.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!hasApiKey) ...[
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.vpn_key_rounded,
                            size: 44,
                            color: FilmlyPalette.textMuted,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '未配置 TMDB API 密钥',
                            style: TextStyle(
                              color: FilmlyPalette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '请先前往左侧的“设置”页面输入有效的 TMDB API Key。',
                            style: TextStyle(
                              color: FilmlyPalette.textSecondary,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // 搜索与类型过滤
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  key: const Key('re-match_search_input'),
                                  controller: _searchController,
                                  style: const TextStyle(
                                    color: FilmlyPalette.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '输入影片名字搜索...',
                                    hintStyle: TextStyle(
                                      color: FilmlyPalette.textMuted,
                                      fontSize: 13.5,
                                    ),
                                    isCollapsed: true,
                                  ),
                                  onSubmitted: (_) => _performSearch(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilmlyGlassButton(
                        key: const Key('re-match_search_button'),
                        label: '搜索',
                        accent: true,
                        height: 40,
                        onTap: _performSearch,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 类型选择 tabs
                  Row(
                    children: [
                      _tabButton('全部', _FilterType.all),
                      const SizedBox(width: 8),
                      _tabButton('电影', _FilterType.movie),
                      const SizedBox(width: 8),
                      _tabButton('电视剧', _FilterType.tv),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],

                  // 搜索结果
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : _results.isEmpty
                        ? const Center(
                            child: Text(
                              '未找到匹配条目，请修改关键字重新检索。',
                              style: TextStyle(
                                color: FilmlyPalette.textMuted,
                                fontSize: 13.5,
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return _ResultCard(
                                key: Key('re-match_result_$index'),
                                result: item,
                                onTap: () => _applyMatch(item),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),

            // 锁定加载蒙层
            if (_isMatching)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.8),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text(
                          '正在同步更新影片元数据...',
                          style: TextStyle(
                            color: FilmlyPalette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, _FilterType type) {
    final selected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        if (_selectedType != type) {
          setState(() {
            _selectedType = type;
          });
          _performSearch();
        }
      },
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? FilmlyPalette.accent.withValues(alpha: 0.12)
              : FilmlyPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? FilmlyPalette.accent : FilmlyPalette.divider,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? FilmlyPalette.accent
                  : FilmlyPalette.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// 重新匹配结果卡片，支持 Hover 高亮及平滑上浮动画
class _ResultCard extends StatefulWidget {
  const _ResultCard({super.key, required this.result, required this.onTap});

  final TmdbSearchResult result;
  final VoidCallback onTap;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.result.type == MediaType.movie ? '电影' : '电视剧';
    final typeColor = widget.result.type == MediaType.movie
        ? const Color(0xFF2F6BFF)
        : const Color(0xFF9D8CFF);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? FilmlyPalette.surfaceStrong
                : FilmlyPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? FilmlyPalette.accent : FilmlyPalette.divider,
            ),
            boxShadow: _hovered
                ? [
                    const BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 海报小图
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 66,
                  child: widget.result.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: widget.result.posterPath!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.movie_rounded,
                              color: FilmlyPalette.textMuted,
                              size: 20,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.movie_rounded,
                            color: FilmlyPalette.textMuted,
                            size: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // 右侧元数据
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.result.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FilmlyPalette.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 类型标签
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 年份
                    Text(
                      widget.result.releaseDate.length >= 4
                          ? widget.result.releaseDate.substring(0, 4)
                          : '未知年份',
                      style: const TextStyle(
                        color: FilmlyPalette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 简介
                    Text(
                      widget.result.overview.isNotEmpty
                          ? widget.result.overview
                          : '暂无该影片简介数据。',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FilmlyPalette.textSecondary,
                        fontSize: 12,
                        height: 1.4,
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
