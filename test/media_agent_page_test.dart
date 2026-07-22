import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/agent_conversation_repository.dart';
import 'package:open_filmly/data/intelligence/agent_models.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/features/intelligence/media_agent_page.dart';
import 'package:open_filmly/providers/intelligence_providers.dart';

void main() {
  late IntelligenceDatabase intelligence;

  setUp(() {
    intelligence = IntelligenceDatabase.inMemory();
  });

  tearDown(() => intelligence.close());

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 820);
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
}
