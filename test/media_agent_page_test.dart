import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/agent_conversation_repository.dart';
import 'package:open_filmly/data/intelligence/agent_models.dart';
import 'package:open_filmly/data/intelligence/agent_run_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/features/intelligence/media_agent_page.dart';
import 'package:open_filmly/providers/intelligence_providers.dart';

void main() {
  late IntelligenceDatabase intelligence;

  setUp(() {
    intelligence = IntelligenceDatabase.inMemory();
  });

  tearDown(() => intelligence.close());

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(1280, 820),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          intelligenceDatabaseProvider.overrideWithValue(intelligence),
        ],
        child: const MaterialApp(home: MediaAgentPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts as a local draft instead of a blank Agent landing page', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('New conversation'), findsNWidgets(2));
    expect(find.byKey(const Key('agent_conversation_empty')), findsOneWidget);
    expect(find.byKey(const Key('agent_new_conversation')), findsOneWidget);
    expect(find.byKey(const Key('agent_request_input')), findsOneWidget);
    expect(find.byKey(const Key('agent_toggle_archived')), findsOneWidget);
  });

  testWidgets('shows persisted conversations in a desktop history rail', (
    tester,
  ) async {
    final repository = AgentConversationRepository(intelligence);
    await repository.create(id: 'health', title: '影视库健康度');
    await repository.appendMessage(
      conversationId: 'health',
      id: 'health-user',
      role: AgentConversationRole.user,
      content: '分析我的影视库健康度',
    );
    await repository.appendMessage(
      conversationId: 'health',
      id: 'health-model',
      role: AgentConversationRole.model,
      content: '你有 2,277 个影视项目。',
    );

    await pumpPage(tester);

    expect(find.byKey(const Key('agent_conversation_history')), findsOneWidget);
    expect(find.byKey(const Key('agent_conversation_health')), findsOneWidget);
    expect(find.text('影视库健康度'), findsNWidgets(2));
    expect(find.text('你有 2,277 个影视项目。'), findsNWidgets(2));
  });

  testWidgets('opens an inline plan detail drawer on wide desktops', (
    tester,
  ) async {
    final conversations = AgentConversationRepository(intelligence);
    final runs = AgentRunRepository(intelligence);
    final plan = MediaAgentPlan(
      id: 'plan-wide',
      operation: MediaAgentOperation.smartCollection,
      title: '科幻片合集',
      description: 'Preview several titles before creating the collection.',
      preview: List.generate(
        5,
        (index) => AgentPreviewItem(
          title: 'Title $index',
          detail: '202$index',
          mediaId: 'media-$index',
        ),
      ),
      createdAt: DateTime(2026, 7, 22),
    );
    await runs.create(plan);
    await conversations.create(id: 'sci-fi', title: '科幻片智能合集');
    await conversations.appendMessage(
      conversationId: 'sci-fi',
      id: 'sci-fi-user',
      role: AgentConversationRole.user,
      content: '建一个科幻片合集',
    );
    await conversations.appendMessage(
      conversationId: 'sci-fi',
      id: 'sci-fi-model',
      role: AgentConversationRole.model,
      content: '已准备计划。',
      planId: plan.id,
    );
    await runs.assignConversation(plan.id, 'sci-fi');

    await pumpPage(tester, size: const Size(1400, 900));

    expect(find.byKey(const Key('agent_plan_panel')), findsOneWidget);
    expect(find.text('View all 5 titles'), findsOneWidget);

    await tester.tap(find.byKey(const Key('agent_open_plan_detail_plan-wide')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agent_plan_detail_drawer')), findsOneWidget);
    expect(find.byKey(const Key('agent_plan_preview_4')), findsOneWidget);
    expect(find.text('Title 4'), findsOneWidget);
  });

  testWidgets('lists archived conversations from the rail toggle', (
    tester,
  ) async {
    final repository = AgentConversationRepository(intelligence);
    await repository.create(id: 'active', title: '活跃对话');
    await repository.create(id: 'old', title: '归档对话');
    await repository.setArchived('old', archived: true);

    await pumpPage(tester);
    expect(find.text('活跃对话'), findsWidgets);
    expect(find.text('归档对话'), findsNothing);

    await tester.tap(find.byKey(const Key('agent_toggle_archived')));
    await tester.pumpAndSettle();

    expect(find.text('归档对话'), findsWidgets);
    expect(find.text('Active conversations'), findsOneWidget);
  });
}
