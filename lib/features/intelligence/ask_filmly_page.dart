import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/open_player.dart';
import '../../features/player/player_page.dart';
import '../../providers/intelligence_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../services/intelligence/semantic_search_service.dart';

class AskFilmlyPage extends ConsumerStatefulWidget {
  const AskFilmlyPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<AskFilmlyPage> createState() => _AskFilmlyPageState();
}

class _AskFilmlyPageState extends ConsumerState<AskFilmlyPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      _controller.text = initialQuery;
      _query = initialQuery;
    }
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

  Future<void> _openResult(AskFilmlyResult result) async {
    if (result.isScene && result.uri != null) {
      await openPlayer(
        context,
        PlayerArgs(
          uri: result.uri!,
          title: result.title,
          mediaId: result.mediaId,
          startAt: Duration(milliseconds: result.startMs!),
        ),
      );
      return;
    }
    final mediaId = result.mediaId;
    if (mediaId != null && mounted) {
      context.push('/media?id=${Uri.encodeQueryComponent(mediaId)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final results = query.isEmpty
        ? const AsyncData<List<AskFilmlyResult>>([])
        : ref.watch(askFilmlyProvider(query));
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      FilmlyIconButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Ask Filmly',
                        style: TextStyle(
                          color: FilmlyPalette.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '描述一个场景、对白、人物或主题，直接跳到影片中的对应时刻。',
                    style: TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: (value) => setState(() => _query = value),
                    onSubmitted: (_) => setState(() {}),
                    style: const TextStyle(
                      color: FilmlyPalette.textPrimary,
                      fontSize: 17,
                    ),
                    decoration: InputDecoration(
                      hintText: '例如：找所有雨夜等待、纽约夜景或关于时间的对白',
                      prefixIcon: const Icon(Icons.auto_awesome_rounded),
                      filled: true,
                      fillColor: FilmlyPalette.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _results(results)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(AsyncValue<List<AskFilmlyResult>> results) {
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('搜索失败：$error')),
      data: (items) {
        if (_query.trim().isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 28),
              const Text(
                '输入自然语言开始搜索你的影视库',
                textAlign: TextAlign.center,
                style: TextStyle(color: FilmlyPalette.textMuted),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final example in const [
                    '雨夜 长安',
                    '宫崎骏',
                    '关于时间的对白',
                    '赛博朋克但不沉重',
                  ])
                    ActionChip(
                      label: Text(example),
                      onPressed: () => setState(() {
                        _controller.text = example;
                        _query = example;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.push('/intelligence'),
                  icon: const Icon(Icons.hub_outlined, size: 16),
                  label: const Text('还没有字幕结果？先建立 Media Intelligence 索引'),
                ),
              ),
            ],
          );
        }
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('暂时没有找到匹配内容'),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.push('/intelligence'),
                  child: const Text('去索引本地字幕旁车'),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _resultTile(items[index]),
        );
      },
    );
  }

  Widget _resultTile(AskFilmlyResult result) {
    final timestamp = result.startMs == null
        ? ''
        : _formatTimestamp(Duration(milliseconds: result.startMs!));
    return InkWell(
      onTap: () => _openResult(result),
      borderRadius: BorderRadius.circular(16),
      child: FilmlyGlassPanel(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              result.isScene
                  ? Icons.play_circle_outline_rounded
                  : Icons.movie_outlined,
              color: FilmlyPalette.accent,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (result.snippet.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        result.snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [
                        result.reason,
                        if (timestamp.isNotEmpty) timestamp,
                      ].join(' · '),
                      style: const TextStyle(
                        color: FilmlyPalette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (result.isScene) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Duration value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.inHours)}:${two(value.inMinutes.remainder(60))}:${two(value.inSeconds.remainder(60))}';
  }
}
