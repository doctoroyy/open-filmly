import 'spoiler_guard_service.dart';
import 'transcript_service.dart';
import 'ai_chat_provider.dart';

class CompanionCitation {
  const CompanionCitation({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String text;
}

class CompanionResponse {
  const CompanionResponse({required this.text, required this.citations});

  final String text;
  final List<CompanionCitation> citations;
}

class MediaContextService {
  MediaContextService(
    this._transcripts, {
    SpoilerGuardService? spoilerGuard,
    this._chatProvider,
  }) : _spoilerGuard = spoilerGuard ?? const SpoilerGuardService();

  final TranscriptService _transcripts;
  final SpoilerGuardService _spoilerGuard;
  final AiChatProvider? _chatProvider;

  Future<CompanionResponse> answer({
    required String assetId,
    required String question,
    required int positionMs,
    String title = '',
  }) async {
    final safe = _spoilerGuard.visibleBefore(
      await _transcripts.getByAsset(assetId),
      positionMs,
    );
    if (safe.isEmpty) {
      return const CompanionResponse(
        text: '当前播放位置之前还没有可用的 AI 内容。',
        citations: [],
      );
    }

    final provider = _chatProvider;
    if (provider != null) {
      final result = await provider.answer(
        title: title,
        question: question,
        positionMs: positionMs,
        context: [
          for (final segment in safe)
            AiChatContextSegment(
              startMs: segment.startMs,
              endMs: segment.endMs,
              text: segment.text,
            ),
        ],
      );
      final citations = result.citations
          .where(
            (citation) =>
                citation.startMs >= 0 &&
                citation.endMs >= citation.startMs &&
                citation.endMs <= positionMs,
          )
          .map(
            (citation) => CompanionCitation(
              startMs: citation.startMs,
              endMs: citation.endMs,
              text: citation.reason,
            ),
          )
          .toList(growable: false);
      return CompanionResponse(text: result.text, citations: citations);
    }

    final terms = question
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 1)
        .toList(growable: false);
    final matches = safe
        .where((segment) {
          final lower = segment.text.toLowerCase();
          return terms.isEmpty || terms.any(lower.contains);
        })
        .take(3)
        .toList(growable: false);
    final selected = matches.isEmpty
        ? safe.reversed.take(3).toList().reversed.toList(growable: false)
        : matches;
    return CompanionResponse(
      text: '根据你已经看到的内容：${selected.map((segment) => segment.text).join(' ')}',
      citations: [
        for (final segment in selected)
          CompanionCitation(
            startMs: segment.startMs,
            endMs: segment.endMs,
            text: segment.text,
          ),
      ],
    );
  }
}
