import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/intelligence_providers.dart';
import '../../services/intelligence/media_context_service.dart';

class CompanionSheet extends ConsumerStatefulWidget {
  const CompanionSheet({
    super.key,
    required this.assetId,
    required this.positionMs,
    required this.title,
  });

  final String assetId;
  final int positionMs;
  final String title;

  @override
  ConsumerState<CompanionSheet> createState() => _CompanionSheetState();
}

class _CompanionSheetState extends ConsumerState<CompanionSheet> {
  final _controller = TextEditingController();
  CompanionResponse? _response;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    setState(() => _loading = true);
    try {
      final response = await ref
          .read(mediaContextServiceProvider)
          .answer(
            assetId: widget.assetId,
            question: question,
            positionMs: widget.positionMs,
            title: widget.title,
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
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI Companion · ${widget.title}',
              style: const TextStyle(fontWeight: FontWeight.w700),
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
                const SizedBox(height: 10),
                Text(
                  '依据：${_response!.citations.map((citation) => _format(citation.startMs)).join('、')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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
