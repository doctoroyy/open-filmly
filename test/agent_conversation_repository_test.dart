import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/agent_conversation_repository.dart';
import 'package:open_filmly/data/intelligence/agent_models.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';

void main() {
  late IntelligenceDatabase database;
  late AgentConversationRepository repository;

  setUp(() {
    database = IntelligenceDatabase.inMemory();
    repository = AgentConversationRepository(database);
  });

  tearDown(() => database.close());

  test(
    'persists messages in order and updates the conversation preview',
    () async {
      await repository.create(
        id: 'conversation-a',
        title: '影视库健康度',
        createdAt: DateTime(2026, 7, 22, 9),
      );
      await repository.appendMessage(
        conversationId: 'conversation-a',
        id: 'message-1',
        role: AgentConversationRole.user,
        content: '分析我的影视库健康度',
        createdAt: DateTime(2026, 7, 22, 9, 1),
      );
      await repository.appendMessage(
        conversationId: 'conversation-a',
        id: 'message-2',
        role: AgentConversationRole.model,
        content: '已分析完成。',
        toolsUsed: const ['inspect_metadata_health'],
        planId: 'plan-a',
        createdAt: DateTime(2026, 7, 22, 9, 2),
      );

      final messages = await repository.listMessages('conversation-a');
      final conversation = await repository.getById('conversation-a');

      expect(messages.map((item) => item.sequence), [0, 1]);
      expect(messages.last.toolsUsed, ['inspect_metadata_health']);
      expect(messages.last.planId, 'plan-a');
      expect(conversation?.preview, '已分析完成。');
      expect(await repository.conversationIdsWithPlans(), {'conversation-a'});
    },
  );

  test('pins, archives, and deletes only conversation records', () async {
    await repository.create(id: 'first', title: '第一段对话');
    await repository.create(id: 'second', title: '第二段对话');
    await repository.setPinned('second', pinned: true);

    expect((await repository.list()).map((item) => item.id), [
      'second',
      'first',
    ]);

    await repository.setArchived('second', archived: true);
    expect((await repository.list()).map((item) => item.id), ['first']);
    expect(
      (await repository.list(includeArchived: true)).map((item) => item.id),
      contains('second'),
    );

    await repository.deleteById('first');
    expect(await repository.getById('first'), isNull);
    expect(await repository.listMessages('first'), isEmpty);
  });
}
