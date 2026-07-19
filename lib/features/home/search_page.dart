import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/rating_formatter.dart';
import '../../core/router/app_router.dart';
import '../../data/models/media.dart';
import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';

/// Full-page search for the mobile tab bar (no overlay / ActionSheet).
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openMedia(Media media) {
    context.push(mediaDetailLocation(media.id));
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().isEmpty
        ? const <Media>[]
        : (ref.watch(mediaSearchProvider(_query)).asData?.value ??
              const <Media>[]);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: '搜索影片、剧集…',
                hintStyle: const TextStyle(color: FilmlyPalette.textMuted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: FilmlyPalette.textMuted,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: FilmlyPalette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? const Center(
                    child: Text(
                      '输入片名开始搜索',
                      style: TextStyle(color: FilmlyPalette.textMuted),
                    ),
                  )
                : results.isEmpty
                ? const Center(
                    child: Text(
                      '没有找到匹配内容',
                      style: TextStyle(color: FilmlyPalette.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final media = results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        title: Text(
                          media.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FilmlyPalette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [
                            media.type == MediaType.tv ? '电视剧' : '电影',
                            if (media.year.isNotEmpty) media.year,
                            ?formatRating(media.rating),
                          ].join(' · '),
                          style: const TextStyle(
                            color: FilmlyPalette.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => _openMedia(media),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
