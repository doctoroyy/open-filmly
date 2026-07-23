import 'dart:convert';

import 'package:http/http.dart' as http;

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

typedef CompanionModelResponder =
    Future<String> Function({
      required String question,
      required String safeContext,
      required int positionMs,
    });

class MediaContextService {
  MediaContextService(
    this._transcripts, {
    this.contentSegments,
    this.modelResponder,
    SpoilerGuardService? spoilerGuard,
  }) : _spoilerGuard = spoilerGuard ?? const SpoilerGuardService();

  final TranscriptService _transcripts;
  final ContentSegmentService? contentSegments;
  final CompanionModelResponder? modelResponder;
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
    final lineMatches = _rankLines(safe, terms).take(5).toList(growable: false);
    final scenes = await contentSegments?.listByAsset(assetId) ?? const [];
    final visibleScenes = scenes
        .where((scene) => scene.endMs <= positionMs)
        .toList(growable: false);
    final sceneMatches = _rankScenes(visibleScenes, terms).take(2).toList();

    final citations = <CompanionCitation>[
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
    ];

    if (citations.isEmpty) {
      final recent = safe.reversed.take(4).toList().reversed.toList();
      citations.addAll([
        for (final segment in recent)
          CompanionCitation(
            startMs: segment.startMs,
            endMs: segment.endMs,
            text: segment.text,
          ),
      ]);
    }

    final safeContext = citations
        .map(
          (item) =>
              '[${_format(item.startMs)}-${_format(item.endMs)}] ${item.text}',
        )
        .join('\n');

    final responder = modelResponder;
    if (responder != null) {
      try {
        final text = await responder(
          question: question,
          safeContext: safeContext,
          positionMs: positionMs,
        );
        if (text.trim().isNotEmpty) {
          return CompanionResponse(text: text.trim(), citations: citations);
        }
      } catch (_) {
        // Fall back to extractive answer.
      }
    }

    final buffer = StringBuffer('根据你已经看到的内容：');
    buffer.write(citations.map((item) => item.text).join(' '));
    return CompanionResponse(text: buffer.toString(), citations: citations);
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

  String _format(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
  }
}

/// Optional Gemini companion that only sees spoiler-safe transcript context.
class GeminiCompanionResponder {
  GeminiCompanionResponder({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    this.client,
  });

  final String apiKey;
  final String model;
  final http.Client? client;

  Future<String> call({
    required String question,
    required String safeContext,
    required int positionMs,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Gemini API Key missing');
    }
    final requestClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      );
      final response = await requestClient.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey.trim(),
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      '你是 Open Filmly 的 AI Companion。用户当前播放到 ${_format(positionMs)}。\n'
                      '你只能根据“已看过的内容”回答，严禁剧透后续剧情。\n'
                      '如果上下文不足以回答，就明确说不知道，并建议回看相关时间点。\n'
                      '用简洁中文回答。\n\n'
                      '已看过的内容：\n$safeContext\n\n'
                      '用户问题：$question',
                },
              ],
            },
          ],
          'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 512},
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Gemini companion failed: ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return '';
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) return '';
      final content = candidates.first['content'];
      if (content is! Map) return '';
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) return '';
      return parts
          .map((part) => part is Map ? part['text']?.toString() ?? '' : '')
          .join()
          .trim();
    } finally {
      if (ownsClient) requestClient.close();
    }
  }

  String _format(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
  }
}
