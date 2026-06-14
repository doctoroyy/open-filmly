import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';

import '../data/models/media.dart';
import '../providers/data_providers.dart';
import 'filmly_design.dart';

/// Full-screen, route-agnostic search overlay.
///
/// Opened via [GlobalSearch.show] from the sidebar button or the Cmd/Ctrl+F
/// shortcut. Queries [mediaSearchProvider] live and navigates to a media
/// detail page on selection.
class GlobalSearch {
  const GlobalSearch._();

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '搜索',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _GlobalSearchSheet();
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _GlobalSearchSheet extends ConsumerStatefulWidget {
  const _GlobalSearchSheet();

  @override
  ConsumerState<_GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<_GlobalSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openMedia(Media media) {
    Navigator.of(context).pop();
    context.push(mediaDetailLocation(media.id));
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _query.trim();
    final resultsAsync = trimmed.isEmpty
        ? const AsyncData<List<Media>>([])
        : ref.watch(mediaSearchProvider(trimmed));

    return Align(
      key: const Key('global_search_overlay'),
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: FilmlyPalette.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FilmlyPalette.divider),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 40,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _searchField(),
                    const SizedBox(height: 12),
                    Flexible(child: _results(trimmed, resultsAsync)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Row(
      children: [
        const Icon(
          Icons.search_rounded,
          color: FilmlyPalette.textSecondary,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: const Key('global_search_field'),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (_) => _maybeOpenFirstResult(),
            style: const TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: FilmlyPalette.accent,
            decoration: const InputDecoration(
              hintText: '搜索全部影片、剧集…',
              hintStyle: TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: FilmlyPalette.textSecondary,
          ),
          tooltip: '关闭 (Esc)',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  void _maybeOpenFirstResult() {
    final trimmed = _query.trim();
    if (trimmed.isEmpty) return;
    final results = ref.read(mediaSearchProvider(trimmed)).asData?.value;
    if (results != null && results.isNotEmpty) {
      _openMedia(results.first);
    }
  }

  Widget _results(String trimmed, AsyncValue<List<Media>> resultsAsync) {
    if (trimmed.isEmpty) {
      return _hint('输入关键词以搜索整个媒体库');
    }
    return resultsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => _hint('搜索失败：$e'),
      data: (items) {
        if (items.isEmpty) {
          return _hint('没有找到与 “$trimmed” 相关的内容');
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) => _resultTile(items[index]),
        );
      },
    );
  }

  Widget _resultTile(Media media) {
    return InkWell(
      onTap: () => _openMedia(media),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF66A3FF).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                media.type == MediaType.tv
                    ? Icons.live_tv_rounded
                    : Icons.movie_rounded,
                color: const Color(0xFF66A3FF),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FilmlyPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (media.year.isNotEmpty)
                    Text(
                      media.year,
                      style: const TextStyle(
                        color: FilmlyPalette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (media.rating != null && media.rating!.isNotEmpty)
              Text(
                '★ ${media.rating}',
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hint(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: FilmlyPalette.textMuted, fontSize: 14),
        ),
      ),
    );
  }
}
