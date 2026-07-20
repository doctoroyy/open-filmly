import 'ai_provider.dart';

/// Applies deterministic, context-safe cleanup before transcript rows are
/// persisted. It deliberately does not invent words or change timestamps;
/// a future model-backed corrector can implement the same boundary.
class TranscriptCorrectionService {
  const TranscriptCorrectionService();

  TranscriptionResult correct(TranscriptionResult input) {
    final ordered = [...input.segments]
      ..sort((a, b) {
        final start = a.startMs.compareTo(b.startMs);
        return start == 0 ? a.endMs.compareTo(b.endMs) : start;
      });

    var previousStart = 0;
    final segments = <ProviderTranscriptSegment>[];
    for (final segment in ordered) {
      final start = segment.startMs < 0
          ? previousStart
          : segment.startMs < previousStart
          ? previousStart
          : segment.startMs;
      final end = segment.endMs <= start ? start + 1 : segment.endMs;
      final text = _cleanText(segment.text);
      if (text.isEmpty) continue;
      segments.add(
        ProviderTranscriptSegment(
          startMs: start,
          endMs: end,
          text: text,
          language: segment.language,
          confidence: segment.confidence,
          speaker: segment.speaker,
        ),
      );
      previousStart = start;
    }
    return TranscriptionResult(language: input.language, segments: segments);
  }

  String _cleanText(String value) => value
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'([.!?。！？])\1+'), (match) => match.group(1)!);
}
