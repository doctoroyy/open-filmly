import '../../data/intelligence/agent_conversation_repository.dart';
import '../../data/intelligence/agent_models.dart';
import '../../data/intelligence/agent_run_repository.dart';
import 'agent_planner.dart';
import 'conversational_agent_engine.dart';

typedef AgentConversationResponder =
    Future<ConversationalTurnResult> Function({
      required String userPrompt,
      required List<AgentModelContextMessage> context,
    });

class AgentConversationTurn {
  const AgentConversationTurn({
    required this.conversation,
    required this.userMessage,
    required this.responseMessage,
  });

  final AgentConversation conversation;
  final AgentConversationMessage userMessage;
  final AgentConversationMessage responseMessage;
}

/// Coordinates a durable conversation with a request-scoped Agent turn. The
/// service deliberately owns title generation, bounded context, and failure
/// persistence so UI routes cannot accidentally create transient transcripts.
class AgentConversationService {
  AgentConversationService({
    required this.conversations,
    required this.runs,
    required this.responder,
  });

  final AgentConversationRepository conversations;
  final AgentRunRepository runs;
  final AgentConversationResponder responder;

  Future<List<AgentConversation>> listConversations({
    bool includeArchived = false,
  }) => conversations.list(includeArchived: includeArchived);

  Future<AgentConversation?> getConversation(String id) =>
      conversations.getById(id);

  Future<List<AgentConversationMessage>> listMessages(String conversationId) =>
      conversations.listMessages(conversationId);

  Future<void> rename(String id, String value) =>
      conversations.rename(id, value);

  Future<void> setPinned(String id, {required bool pinned}) =>
      conversations.setPinned(id, pinned: pinned);

  Future<void> setArchived(String id, {required bool archived}) =>
      conversations.setArchived(id, archived: archived);

  Future<void> delete(String id) => conversations.deleteById(id);

  Future<AgentConversationTurn> send({
    String? conversationId,
    required String text,
  }) async {
    final prompt = text.trim();
    if (prompt.isEmpty) {
      throw const AgentPlannerException('请输入有效的对话内容');
    }

    var conversation = conversationId == null
        ? null
        : await conversations.getById(conversationId);
    if (conversation == null) {
      final now = DateTime.now();
      conversation = await conversations.create(
        id: _newId('conversation', now),
        title: _titleFrom(prompt),
        createdAt: now,
      );
    }

    final userMessage = await conversations.appendMessage(
      conversationId: conversation.id,
      id: _newId('message', DateTime.now()),
      role: AgentConversationRole.user,
      content: prompt,
    );

    final allMessages = await conversations.listMessages(conversation.id);
    final context = _boundedContext(
      allMessages.where((message) => message.id != userMessage.id),
    );

    try {
      final result = await responder(userPrompt: prompt, context: context);
      final planId = result.plan?.id;
      if (planId != null && planId.isNotEmpty) {
        await runs.assignConversation(planId, conversation.id);
      }
      final response = await conversations.appendMessage(
        conversationId: conversation.id,
        id: _newId('message', DateTime.now()),
        role: AgentConversationRole.model,
        content: result.replyText,
        toolsUsed: result.toolsUsed,
        planId: planId,
      );
      return AgentConversationTurn(
        conversation: (await conversations.getById(conversation.id))!,
        userMessage: userMessage,
        responseMessage: response,
      );
    } catch (_) {
      final response = await conversations.appendMessage(
        conversationId: conversation.id,
        id: _newId('message', DateTime.now()),
        role: AgentConversationRole.system,
        content: '暂时无法完成这次回答。请检查 AI Provider 设置后重试。',
        status: AgentConversationMessageStatus.failed,
      );
      return AgentConversationTurn(
        conversation: (await conversations.getById(conversation.id))!,
        userMessage: userMessage,
        responseMessage: response,
      );
    }
  }

  List<AgentModelContextMessage> _boundedContext(
    Iterable<AgentConversationMessage> messages,
  ) {
    final visible = messages
        .where(
          (message) =>
              message.status == AgentConversationMessageStatus.complete &&
              (message.role == AgentConversationRole.user ||
                  message.role == AgentConversationRole.model) &&
              message.content.trim().isNotEmpty,
        )
        .toList(growable: false);
    final start = visible.length > 12 ? visible.length - 12 : 0;
    return visible
        .skip(start)
        .map(
          (message) => AgentModelContextMessage(
            role: message.role,
            content: message.content,
          ),
        )
        .toList(growable: false);
  }

  String _newId(String prefix, DateTime timestamp) =>
      '$prefix-${timestamp.microsecondsSinceEpoch}';

  String _titleFrom(String prompt) {
    final normalized = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    final title = normalized.length <= 36
        ? normalized
        : normalized.substring(0, 36);
    return title.isEmpty ? '新对话' : title;
  }
}
