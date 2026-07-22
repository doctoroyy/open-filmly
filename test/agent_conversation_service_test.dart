import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/agent_conversation_repository.dart';
import 'package:open_filmly/data/intelligence/agent_models.dart';
import 'package:open_filmly/data/intelligence/agent_run_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/services/intelligence/agent_conversation_service.dart';
import 'package:open_filmly/services/intelligence/conversational_agent_engine.dart';

void main() {
  late IntelligenceDatabase database;
  late List<List<String>> contexts;
  late AgentConversationService service;

  setUp(() {
    database = IntelligenceDatabase.inMemory();
    contexts = [];
    service = AgentConversationService(
      conversations: AgentConversationRepository(database),
      runs: AgentRunRepository(database),
      responder: ({required userPrompt, required context}) async {
        contexts.add(context.map((message) => message.content).toList());
        return ConversationalTurnResult(replyText: '回答：$userPrompt');
      },
    );
  });

  tearDown(() => database.close());

  test('keeps provider context scoped to the selected conversation', () async {
    final first = await service.send(text: '第一段对话');
    await service.send(conversationId: first.conversation.id, text: '继续第一段');
    final second = await service.send(text: '第二段对话');

    expect(contexts, [
      isEmpty,
      ['第一段对话', '回答：第一段对话'],
      isEmpty,
    ]);
    expect(second.conversation.title, '第二段对话');
    expect(
      (await service.listMessages(
        second.conversation.id,
      )).map((message) => message.content),
      ['第二段对话', '回答：第二段对话'],
    );
  });

  test(
    'keeps the user message and adds a local failure record on error',
    () async {
      final failing = AgentConversationService(
        conversations: AgentConversationRepository(database),
        runs: AgentRunRepository(database),
        responder: ({required userPrompt, required context}) async {
          throw StateError('provider unavailable');
        },
      );

      final turn = await failing.send(text: '帮我整理重复文件');
      final messages = await failing.listMessages(turn.conversation.id);

      expect(messages, hasLength(2));
      expect(messages.first.content, '帮我整理重复文件');
      expect(messages.last.status.name, 'failed');
    },
  );

  test('links a persisted plan back to its originating conversation', () async {
    final runs = AgentRunRepository(database);
    final plan = MediaAgentPlan(
      id: 'plan-collection',
      operation: MediaAgentOperation.smartCollection,
      title: '建立智能合集',
      description: 'Preview 1 item',
      preview: const [AgentPreviewItem(title: 'Arrival', detail: '2016')],
      createdAt: DateTime(2026, 7, 22),
    );
    await runs.create(plan);
    final planning = AgentConversationService(
      conversations: AgentConversationRepository(database),
      runs: runs,
      responder: ({required userPrompt, required context}) async {
        return ConversationalTurnResult(replyText: '已准备计划。', plan: plan);
      },
    );

    final turn = await planning.send(text: '建一个科幻片合集');
    final run = await runs.getById(plan.id);

    expect(run?.conversationId, turn.conversation.id);
    expect(
      (await planning.listMessages(turn.conversation.id)).last.planId,
      plan.id,
    );
  });
}
