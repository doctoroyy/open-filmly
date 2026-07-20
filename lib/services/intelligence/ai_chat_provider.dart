import 'dart:convert';
import 'dart:io';

class AiChatContextSegment {
  const AiChatContextSegment({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String text;

  Map<String, dynamic> toJson() => {
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
  };
}

class AiChatCitation {
  const AiChatCitation({
    required this.startMs,
    required this.endMs,
    required this.reason,
  });

  final int startMs;
  final int endMs;
  final String reason;
}

class AiChatProviderResult {
  const AiChatProviderResult({required this.text, required this.citations});

  final String text;
  final List<AiChatCitation> citations;
}

abstract interface class AiChatProvider {
  String get id;

  Future<AiChatProviderResult> answer({
    required String title,
    required String question,
    required int positionMs,
    required List<AiChatContextSegment> context,
  });
}

/// HTTP adapter for an explicitly configured text-only endpoint.
///
/// The endpoint receives transcript context, never a media path or video
/// bytes. It must return `{answer, citations:[{startMs,endMs,reason}]}`.
class HttpAiChatProvider implements AiChatProvider {
  const HttpAiChatProvider({required this.endpoint, this.apiKey = ''});

  final String endpoint;
  final String apiKey;

  @override
  String get id => 'remote-chat';

  @override
  Future<AiChatProviderResult> answer({
    required String title,
    required String question,
    required int positionMs,
    required List<AiChatContextSegment> context,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(endpoint));
      request.headers.contentType = ContentType.json;
      if (apiKey.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${apiKey.trim()}',
        );
      }
      request.write(
        jsonEncode({
          'title': title,
          'question': question,
          'positionMs': positionMs,
          'context': context
              .map((item) => item.toJson())
              .toList(growable: false),
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'AI chat endpoint returned ${response.statusCode}',
          uri: request.uri,
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('Invalid AI chat response');
      }
      final map = Map<String, dynamic>.from(decoded);
      final rawCitations = map['citations'];
      return AiChatProviderResult(
        text: map['answer']?.toString() ?? map['text']?.toString() ?? '',
        citations: rawCitations is List
            ? rawCitations
                  .whereType<Map>()
                  .map((value) {
                    final item = Map<String, dynamic>.from(value);
                    return AiChatCitation(
                      startMs: (item['startMs'] as num?)?.round() ?? 0,
                      endMs: (item['endMs'] as num?)?.round() ?? 0,
                      reason: item['reason']?.toString() ?? '',
                    );
                  })
                  .toList(growable: false)
            : const [],
      );
    } finally {
      client.close(force: true);
    }
  }
}
