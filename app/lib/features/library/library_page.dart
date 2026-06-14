import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

import '../../data/models/media.dart';
import '../../data/models/media_library_query.dart';
import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../widgets/filmly_error_state.dart';
import '../../widgets/media_poster_card.dart';
import '../../widgets/responsive_media_grid.dart';

/// Poster-wall library page with search + sorting.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({
    super.key,
    required this.type,
    this.customTitle,
    this.genreTerms = const [],
  });

  final MediaType? type;
  final String? customTitle;
  final List<String> genreTerms;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchController = TextEditingController();
  String _searchTerm = '';
  MediaSort _sort = MediaSort.title;

  String get _title =>
      widget.customTitle ??
      switch (widget.type) {
        MediaType.movie => '电影',
        MediaType.tv => '剧集',
        MediaType.unknown => '未分类',
        null => '媒体库',
      };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final query = MediaLibraryQuery(
      type: widget.type,
      searchTerm: _searchTerm,
      sort: _sort,
      genreTerms: widget.genreTerms,
    );
    final async = ref.watch(mediaBrowseProvider(query));
    final itemCount = async.asData?.value.length;

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
                  onTap: () => _goBack(context),
                ),
                title: _title,
                subtitle: itemCount == null ? '正在整理内容' : '共 $itemCount 部',
              ),
              const SizedBox(height: 24),
              _controls(context),
              const SizedBox(height: 22),
              Expanded(
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => FilmlyErrorState(
                    message: '加载失败：$e',
                    onRetry: () => ref.invalidate(mediaBrowseProvider(query)),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return _searchTerm.trim().isEmpty
                          ? _emptyLibrary(context)
                          : _emptySearch(context);
                    }
                    return _results(context, items);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxWidth < 960;
        final searchField = FilmlySearchField(
          controller: _searchController,
          hintText: '搜索$_title...',
          onChanged: (value) => setState(() => _searchTerm = value),
          value: _searchTerm,
        );
        final sortField = FilmlyGlassPanel(
          height: 48,
          borderRadius: BorderRadius.circular(24),
          color: FilmlyPalette.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MediaSort>(
              value: _sort,
              dropdownColor: FilmlyPalette.background,
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: FilmlyPalette.textSecondary,
                size: 18,
              ),
              items: MediaSort.values
                  .map(
                    (sort) =>
                        DropdownMenuItem(value: sort, child: Text(sort.label)),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _sort = value);
              },
            ),
          ),
        );

        if (compactLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [searchField, const SizedBox(height: 12), sortField],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 16),
            sortField,
          ],
        );
      },
    );
  }

  Widget _results(BuildContext context, List<Media> items) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Text(
          _searchTerm.trim().isEmpty
              ? '共 ${items.length} 部'
              : '找到 ${items.length} 部',
          style: const TextStyle(
            color: FilmlyPalette.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 18),
        ResponsiveMediaGrid(
          spacing: 20,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final media = items[index];
            return MediaPosterCard(
              key: Key('library_media_${media.title}'),
              media: media,
              heroTag: 'poster_${media.id}',
              onTap: () => context.push(mediaDetailLocation(media.id)),
            );
          },
        ),
      ],
    );
  }

  Widget _emptyLibrary(BuildContext context) {
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
              Icons.video_library_outlined,
              size: 34,
              color: FilmlyPalette.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '还没有$_title内容',
            style: const TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '添加来源并扫描后，内容将自动出现',
            style: TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
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

  Widget _emptySearch(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: FilmlyPalette.surface,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 32,
              color: FilmlyPalette.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '未找到 “$_searchTerm” 的相关内容',
            style: const TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
