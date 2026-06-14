import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../widgets/filmly_error_state.dart';
import '../../widgets/media_poster_card.dart';
import '../../widgets/responsive_media_grid.dart';

/// Poster wall of the user's favorited items.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilmlyInlineHeader(
                leading: FilmlyIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                ),
                title: '我的收藏',
                subtitle: async.asData?.value.isEmpty ?? true
                    ? '收藏喜欢的影片，方便随时回看。'
                    : '共 ${async.asData!.value.length} 部',
              ),
              const SizedBox(height: 24),
              Expanded(
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => FilmlyErrorState(
                    message: '加载失败：$e',
                    onRetry: () => ref.invalidate(favoritesProvider),
                  ),
                  data: (items) {
                    if (items.isEmpty) return _empty(context);
                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        ResponsiveMediaGrid(
                          spacing: 20,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final media = items[index];
                            return MediaPosterCard(
                              media: media,
                              heroTag: 'poster_${media.id}',
                              onTap: () =>
                                  context.push(mediaDetailLocation(media.id)),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: FilmlyPalette.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 34,
              color: FilmlyPalette.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '还没有收藏',
            style: TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '在影片详情页点击 ♥ 即可收藏。',
            style: TextStyle(color: FilmlyPalette.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
