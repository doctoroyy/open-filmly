import '../../data/intelligence/intelligence_models.dart';
import 'content_segment_service.dart';
import 'spoiler_guard_service.dart';
import 'transcript_service.dart';

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
    this.contentSegments,
    SpoilerGuardService? spoilerGuard,
  }) : _spoilerGuard = spoilerGuard ?? const SpoilerGuardService();

  final TranscriptService _transcripts;
  final ContentSegmentService? contentSegments;
  final SpoilerGuardService _spoilerGuard;

  Future<CompanionResponse> answer({
    required String assetId,
    required String question,
    required int positionMs,
  }) async {
    final all = await _transcripts.getByAsset(assetId);
    final safe = _spoilerGuard.visibleBefore(all, positionMs);
    if (safe.isEmpty) {
      return const CompanionResponse(
        text: '当前播放位置之前还没有可用的 AI 内容。可以先导入字幕旁车，或在设置里对影片生成 AI 字幕。',
        citations: [],
      );
    }

    final terms = _terms(question);
    final lineMatches = _rankLines(safe, terms).take(4).toList(growable: false);

    final scenes = await contentSegments?.listByAsset(assetId) ?? const [];
    final visibleScenes = scenes
        .where((scene) => scene.endMs <= positionMs)
        .toList(growable: false);
    final sceneMatches = _rankScenes(visibleScenes, terms).take(2).toList();

    if (lineMatches.isEmpty && sceneMatches.isEmpty) {
      final recent = safe.reversed.take(3).toList().reversed.toList();
      return CompanionResponse(
        text: '根据你已经看到的最近内容：${recent.map((s) => s.text).join(' ')}',
        citations: [
          for (final segment in recent)
            CompanionCitation(
              startMs: segment.startMs,
              endMs: segment.endMs,
              text: segment.text,
            ),
        ],
      );
    }

    final buffer = StringBuffer('根据你已经看到的内容：');
    if (sceneMatches.isNotEmpty) {
      buffer.write(
        sceneMatches
            .map((scene) => '【${scene.title}】${scene.summary}')
            .join(' '),
      );
      if (lineMatches.isNotEmpty) buffer.write(' ');
    }
    if (lineMatches.isNotEmpty) {
      buffer.write(lineMatches.map((line) => line.text).join(' '));
    }

    return CompanionResponse(
      text: buffer.toString(),
      citations: [
        for (final scene in sceneMatches)
          CompanionCitation(
            startMs: scene.startMs,
            endMs: scene.endMs,
            text: scene.summary,
          ),
        for (final segment in lineMatches)
          CompanionCitation(
            startMs: segment.startMs,
            endMs: segment.endMs,
            text: segment.text,
          ),
      ],
    );
  }

  List<String> _terms(String question) {
    final lower = question.toLowerCase().trim();
    final tokens = <String>[];
    for (final part in lower.split(RegExp(r'[\s,，。？?！!、]+'))) {
      if (part.isEmpty) continue;
      if (RegExp(r'[\u3400-\u9fff]').hasMatch(part)) {
        if (part.length >= 2) tokens.add(part);
        for (final rune in part.runes) {
          tokens.add(String.fromCharCode(rune));
        }
      } else if (part.length > 1) {
        tokens.add(part);
      }
    }
    return tokens.toSet().toList(growable: false);
  }

  List<TranscriptSegment> _rankLines(
    List<TranscriptSegment> lines,
    List<String> terms,
  ) {
    if (terms.isEmpty) return lines.reversed.take(3).toList().reversed.toList();
    final scored = <({TranscriptSegment segment, int score})>[];
    for (final line in lines) {
      final haystack =
          '${line.text} ${line.translatedText ?? ''}'.toLowerCase();
      var score = 0;
      for (final term in terms) {
        if (haystack.contains(term)) score += term.length > 1 ? 2 : 1;
      }
      if (score > 0) scored.add((segment: line, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((item) => item.segment).toList(growable: false);
  }

  List<ContentSegment> _rankScenes(
    List<ContentSegment> scenes,
    List<String> terms,
  ) {
    if (scenes.isEmpty) return const [];
    if (terms.isEmpty) return scenes.reversed.take(1).toList();
    final scored = <({ContentSegment scene, int score})>[];
    for (final scene in scenes) {
      final haystack =
          '${scene.title} ${scene.summary} ${scene.searchText}'.toLowerCase();
      var score = 0;
      for (final term in terms) {
        if (haystack.contains(term)) score += term.length > 1 ? 2 : 1;
      }
      if (score > 0) scored.add((scene: scene, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((item) => item.scene).toList(growable: false);
  }
}
