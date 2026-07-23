import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/intelligence_providers.dart';
import '../../services/intelligence/media_context_service.dart';
import '../../widgets/filmly_design.dart';

class CompanionSheet extends ConsumerStatefulWidget {
  const CompanionSheet({
    super.key,
    required this.assetId,
    required this.positionMs,
    required this.title,
    this.onJumpTo,
  });

  final String assetId;
  final int positionMs;
  final String title;
  final Future<void> Function(int positionMs)? onJumpTo;

  @override
  ConsumerState<CompanionSheet> createState() => _CompanionSheetState();
}

class _CompanionSheetState extends ConsumerState<CompanionSheet> {
  final _controller = TextEditingController();
  CompanionResponse? _response;
  bool _loading = false;

  static const _starters = <String>[
    '他是谁？',
    '前面发生了什么？',
    '这里为什么这样说？',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask([String? override]) async {
    final question = (override ?? _controller.text).trim();
    if (question.isEmpty) return;
    if (override != null) _controller.text = override;
    setState(() => _loading = true);
    try {
      final response = await ref
          .read(mediaContextServiceProvider)
          .answer(
            assetId: widget.assetId,
            question: question,
            positionMs: widget.positionMs,
          );
      if (mounted) setState(() => _response = response);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI Companion · ${widget.title}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '只使用当前进度之前的内容，避免剧透 · ${_format(widget.positionMs)}',
              style: const TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final starter in _starters)
                  ActionChip(
                    label: Text(starter),
                    onPressed: _loading ? null : () => _ask(starter),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _ask(),
              decoration: InputDecoration(
                hintText: '他是谁？前面发生了什么？',
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _ask,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ),
            if (_response != null) ...[
              const SizedBox(height: 16),
              Text(_response!.text),
              if (_response!.citations.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '可回看依据',
                  style: TextStyle(
                    color: FilmlyPalette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final citation in _response!.citations)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline_rounded),
                    title: Text(
                      citation.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_format(citation.startMs)),
                    onTap: widget.onJumpTo == null
                        ? null
                        : () async {
                            await widget.onJumpTo!(citation.startMs);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _format(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
  }
}
