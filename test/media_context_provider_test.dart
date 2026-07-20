import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/services/intelligence/ai_chat_provider.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/media_context_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test('filters provider citations that cross the current playhead', () async {
    final database = IntelligenceDatabase.inMemory();
    addTearDown(database.close);
    final transcripts = TranscriptService(database);
    await transcripts.saveProviderResult(
      'asset-1',
      const TranscriptionResult(
        language: 'en',
        segments: [
          ProviderTranscriptSegment(startMs: 0, endMs: 1000, text: 'known'),
          ProviderTranscriptSegment(startMs: 1000, endMs: 2000, text: 'future'),
        ],
      ),
    );
    final service = MediaContextService(
      transcripts,
      chatProvider: _FakeChatProvider(),
    );

    final answer = await service.answer(
      assetId: 'asset-1',
      question: 'who is this?',
      positionMs: 1000,
      title: 'Test',
    );

    expect(answer.text, 'provider answer');
    expect(answer.citations, hasLength(1));
    expect(answer.citations.single.startMs, 0);
  });
}

class _FakeChatProvider implements AiChatProvider {
  @override
  String get id => 'fake';

  @override
  Future<AiChatProviderResult> answer({
    required String title,
    required String question,
    required int positionMs,
    required List<AiChatContextSegment> context,
  }) async => const AiChatProviderResult(
    text: 'provider answer',
    citations: [
      AiChatCitation(startMs: 0, endMs: 1000, reason: 'known'),
      AiChatCitation(startMs: 1000, endMs: 2000, reason: 'future'),
    ],
  );
}
