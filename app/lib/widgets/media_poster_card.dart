import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters/rating_formatter.dart';
import '../data/models/media.dart';
import '../providers/data_providers.dart';
import 'filmly_design.dart';

/// Rich poster card with hover motion, play affordance, and metadata badges.
class MediaPosterCard extends ConsumerStatefulWidget {
  const MediaPosterCard({
    super.key,
    required this.media,
    this.onTap,
    this.heroTag,
  });

  final Media media;
  final VoidCallback? onTap;

  /// When set, the poster image becomes a Hero with this tag so it can fly
  /// into the detail page. Only set it where the media is unique on screen.
  final Object? heroTag;

  @override
  ConsumerState<MediaPosterCard> createState() => _MediaPosterCardState();
}

class _MediaPosterCardState extends ConsumerState<MediaPosterCard> {
  bool _hovered = false;

  bool get _supportsHover {
    final platform = Theme.of(context).platform;
    return switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS => false,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final episodeCountAsync = widget.media.type == MediaType.tv
        ? ref.watch(episodeCountProvider(widget.media.id))
        : null;
    final showOverlay = !_supportsHover || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (_supportsHover) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_supportsHover) setState(() => _hovered = false);
      },
      child: GestureDetector(
        key: widget.key,
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.heroTag != null
                          ? Hero(tag: widget.heroTag!, child: _poster(context))
                          : _poster(context),
                      AnimatedOpacity(
                        opacity: showOverlay ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.30),
                          alignment: Alignment.center,
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.media.rating != null &&
                          widget.media.rating!.isNotEmpty)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _ratingBadge(widget.media.rating!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.media.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.media.year.isEmpty ? '—' : widget.media.year,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (episodeCountAsync != null)
                  episodeCountAsync.when(
                    data: (count) => count > 0
                        ? _episodeBadge(count)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _poster(BuildContext context) {
    final posterPath = widget.media.posterPath;
    if (posterPath != null && posterPath.isNotEmpty) {
      if (posterPath.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: posterPath,
          fit: BoxFit.cover,
          placeholder: (_, _) => _loadingPlaceholder(context),
          errorWidget: (_, _, _) => _placeholder(context),
        );
      }
      return Image.file(
        File(posterPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _loadingPlaceholder(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE4E7EB), Color(0xFFEDF0F3)],
        ),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(FilmlyPalette.accent),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE4E7EB), Color(0xFFEDF0F3)],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.media.type == MediaType.tv
                ? Icons.tv_rounded
                : Icons.movie_rounded,
            size: 38,
            color: FilmlyPalette.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            widget.media.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBadge(String rating) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            formatRating(rating) ?? rating,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _episodeBadge(int count) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '共$count集',
            style: const TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
