import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/intelligence/agent_models.dart';
import '../../providers/intelligence_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../widgets/media_command_palette.dart';

/// Provider replies can include lightweight Markdown. The conversation surface
/// is intentionally editorial rather than a document renderer, so formatting
/// markers are removed before painting a compact answer.
String normalizeAgentReply(String value) {
  return value
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'^[ \t]{0,3}#{1,6}[ \t]+', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .trim();
}

/// A durable conversation workspace. `Cmd/Ctrl+K` remains the lightweight
/// command palette; this route is for questions, evidence, and safe plans
/// that need to survive navigation and application relaunch.
class MediaAgentPage extends ConsumerStatefulWidget {
  const MediaAgentPage({super.key, this.initialPrompt, this.conversationId});

  final String? initialPrompt;
  final String? conversationId;

  @override
  ConsumerState<MediaAgentPage> createState() => _MediaAgentPageState();
}

class _MediaAgentPageState extends ConsumerState<MediaAgentPage> {
  static const _railWidth = 248.0;

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  List<AgentConversation> _conversations = const [];
  List<AgentConversationMessage> _messages = const [];
  Map<String, MediaAgentRun> _runs = const {};
  Set<String> _conversationsWithPlans = const {};
  String? _activeConversationId;
  bool _loading = true;
  bool _thinking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialPrompt = widget.initialPrompt?.trim();
      await _loadWorkspace(
        preferredConversationId: widget.conversationId,
        selectLatest: initialPrompt == null || initialPrompt.isEmpty,
      );
      if (initialPrompt?.isNotEmpty == true && mounted) {
        _startNewConversation();
        await _sendMessage(initialPrompt);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  AgentConversation? get _activeConversation {
    final id = _activeConversationId;
    if (id == null) return null;
    for (final conversation in _conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  Future<void> _loadWorkspace({
    String? preferredConversationId,
    bool selectLatest = true,
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) setState(() => _loading = true);
    final service = ref.read(agentConversationServiceProvider);
    final conversations = await service.listConversations();
    final conversationsWithPlans = await service.conversationIdsWithPlans();
    final requestedId = preferredConversationId ?? _activeConversationId;
    final activeId = conversations.any((item) => item.id == requestedId)
        ? requestedId
        : (selectLatest && conversations.isNotEmpty
              ? conversations.first.id
              : null);
    final messages = activeId == null
        ? const <AgentConversationMessage>[]
        : await service.listMessages(activeId);
    final runs = await _loadRuns(messages);

    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _conversationsWithPlans = conversationsWithPlans;
      _activeConversationId = activeId;
      _messages = messages;
      _runs = runs;
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<Map<String, MediaAgentRun>> _loadRuns(
    List<AgentConversationMessage> messages,
  ) async {
    final ids = messages
        .map((message) => message.planId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return const {};
    final repository = ref.read(agentRunRepositoryProvider);
    final entries = await Future.wait(
      ids.map((id) async => MapEntry(id, await repository.getById(id))),
    );
    return {
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<void> _selectConversation(String id) =>
      _loadWorkspace(preferredConversationId: id, selectLatest: false);

  void _startNewConversation() {
    setState(() {
      _activeConversationId = null;
      _messages = const [];
      _runs = const {};
      _error = null;
    });
  }

  Future<void> _sendMessage([String? override]) async {
    final text = (override ?? _inputController.text).trim();
    if (text.isEmpty || _thinking) return;
    _inputController.clear();

    final pending = AgentConversationMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: _activeConversationId ?? 'new',
      sequence: _messages.length,
      role: AgentConversationRole.user,
      content: text,
      status: AgentConversationMessageStatus.complete,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages = [..._messages, pending];
      _thinking = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final service = ref.read(agentConversationServiceProvider);
      final turn = await service.send(
        conversationId: _activeConversationId,
        text: text,
      );
      await _loadWorkspace(
        preferredConversationId: turn.conversation.id,
        selectLatest: false,
        showLoading: false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  Future<void> _confirmPlan(MediaAgentRun run) async {
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final updated = await service.confirm(run.id);
      if (!mounted) return;
      setState(() => _runs = {..._runs, updated.id: updated});
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _executePlan(MediaAgentRun run) async {
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final updated = await service.execute(run.id);
      if (!mounted) return;
      setState(() => _runs = {..._runs, updated.id: updated});
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _undoRun(MediaAgentRun run) async {
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final updated = await service.undo(run.id);
      if (!mounted) return;
      setState(() => _runs = {..._runs, updated.id: updated});
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _handleConversationAction(
    _ConversationAction action,
    AgentConversation conversation,
  ) async {
    final service = ref.read(agentConversationServiceProvider);
    switch (action) {
      case _ConversationAction.rename:
        final value = await _promptRename(conversation);
        if (value != null && value.trim().isNotEmpty) {
          await service.rename(conversation.id, value);
        }
      case _ConversationAction.pin:
        await service.setPinned(conversation.id, pinned: true);
      case _ConversationAction.unpin:
        await service.setPinned(conversation.id, pinned: false);
      case _ConversationAction.archive:
        await service.setArchived(conversation.id, archived: true);
      case _ConversationAction.delete:
        final confirmed = await _confirmDelete(conversation);
        if (!confirmed) return;
        await service.delete(conversation.id);
    }
    if (!mounted) return;
    await _loadWorkspace(selectLatest: true, showLoading: false);
  }

  Future<String?> _promptRename(AgentConversation conversation) async {
    final controller = TextEditingController(text: conversation.title);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          decoration: const InputDecoration(hintText: 'Conversation title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirmDelete(AgentConversation conversation) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete conversation?'),
            content: Text(
              '“${conversation.title}” and its local messages will be removed. Your media, collections, and completed plans will stay intact.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final railVisible = constraints.maxWidth >= 780;
            return Row(
              children: [
                if (railVisible) ...[
                  SizedBox(width: _railWidth, child: _conversationRail()),
                  const VerticalDivider(width: 1, color: Color(0xFFE5E2DC)),
                ],
                Expanded(child: _thread(railVisible: railVisible)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _conversationRail({bool sheet = false}) {
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'CONVERSATIONS',
                style: TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.05,
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('agent_new_conversation'),
            onPressed: () {
              if (sheet) Navigator.of(context).pop();
              _startNewConversation();
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('New conversation'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FilmlyPalette.textPrimary,
              side: const BorderSide(color: Color(0xFFE5E2DC)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
      ),
    ];

    if (_loading) {
      children.add(
        const Expanded(child: Center(child: CircularProgressIndicator())),
      );
    } else if (_conversations.isEmpty) {
      children.add(
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Your saved questions and plans will appear here.',
                style: TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      children.add(Expanded(child: _conversationList(sheet: sheet)));
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFFFFDFC)),
      child: Column(children: children),
    );
  }

  Widget _conversationList({required bool sheet}) {
    final items = <Widget>[];
    String? section;
    for (final conversation in _conversations) {
      final nextSection = _sectionFor(conversation);
      if (section != nextSection) {
        section = nextSection;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Text(
              nextSection.toUpperCase(),
              style: const TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );
      }
      items.add(_conversationRow(conversation, sheet: sheet));
    }
    return ListView(
      key: const Key('agent_conversation_history'),
      padding: const EdgeInsets.only(bottom: 18),
      children: items,
    );
  }

  Widget _conversationRow(
    AgentConversation conversation, {
    required bool sheet,
  }) {
    final active = conversation.id == _activeConversationId;
    final hasPlan = _conversationsWithPlans.contains(conversation.id);
    return InkWell(
      key: Key('agent_conversation_${conversation.id}'),
      onTap: () {
        if (sheet) Navigator.of(context).pop();
        _selectConversation(conversation.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: active ? const Color(0xFF246BDE) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            if (hasPlan)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.brightness_1_rounded,
                  size: 7,
                  color: Color(0xFFA85C16),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (conversation.isPinned) ...[
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 12,
                          color: FilmlyPalette.textMuted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FilmlyPalette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (conversation.preview.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      conversation.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FilmlyPalette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    _relativeTime(conversation.updatedAt),
                    style: const TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_ConversationAction>(
              tooltip: 'Conversation options',
              icon: const Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: FilmlyPalette.textMuted,
              ),
              onSelected: (action) =>
                  _handleConversationAction(action, conversation),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _ConversationAction.rename,
                  child: Text('Rename'),
                ),
                PopupMenuItem(
                  value: conversation.isPinned
                      ? _ConversationAction.unpin
                      : _ConversationAction.pin,
                  child: Text(conversation.isPinned ? 'Unpin' : 'Pin'),
                ),
                const PopupMenuItem(
                  value: _ConversationAction.archive,
                  child: Text('Archive'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: _ConversationAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thread({required bool railVisible}) {
    final conversation = _activeConversation;
    return Column(
      children: [
        _threadHeader(conversation, railVisible: railVisible),
        const Divider(height: 1, color: Color(0xFFE5E2DC)),
        Expanded(child: _threadBody()),
        if (_error != null) _errorPanel(),
        _composer(),
      ],
    );
  }

  Widget _threadHeader(
    AgentConversation? conversation, {
    required bool railVisible,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 20, 14),
      child: Row(
        children: [
          if (!railVisible) ...[
            IconButton(
              tooltip: 'Conversations',
              onPressed: _openConversationSheet,
              icon: const Icon(Icons.forum_outlined),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation?.title ?? 'New conversation',
                  key: const Key('agent_thread_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FilmlyPalette.textPrimary,
                    fontSize: 18,
                    letterSpacing: -0.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  conversation == null
                      ? 'Local draft · saved after your first message'
                      : 'Local conversation · ${_relativeTime(conversation.updatedAt)}',
                  style: const TextStyle(
                    color: FilmlyPalette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('agent_open_command_palette'),
            onPressed: () => MediaCommandPalette.show(context),
            icon: const Icon(Icons.search_rounded, size: 17),
            label: const Text('Search  ⌘K'),
            style: TextButton.styleFrom(
              foregroundColor: FilmlyPalette.textSecondary,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _threadBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) return _emptyThread();
    return ListView.builder(
      controller: _scrollController,
      key: const Key('agent_conversation_thread'),
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 20),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _thinkingIndicator();
        return _messageView(_messages[index]);
      },
    );
  }

  Widget _emptyThread() {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        key: const Key('agent_conversation_empty'),
        padding: const EdgeInsets.fromLTRB(28, 54, 28, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start with a question.',
                style: TextStyle(
                  color: FilmlyPalette.textPrimary,
                  fontSize: 24,
                  letterSpacing: -0.55,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use a conversation when you want an answer with context or a safe library plan. For a title or a scene, press ⌘K.',
                style: TextStyle(
                  color: FilmlyPalette.textSecondary,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _starterPrompt('分析我的影视库健康度'),
                  _starterPrompt('找出没看过的科幻片'),
                  _starterPrompt('给缺字幕的片子生成计划'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _starterPrompt(String text) => TextButton(
    onPressed: _thinking ? null : () => _sendMessage(text),
    style: TextButton.styleFrom(
      foregroundColor: FilmlyPalette.textPrimary,
      backgroundColor: const Color(0xFFFFFDFC),
      side: const BorderSide(color: Color(0xFFE5E2DC)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  Widget _messageView(AgentConversationMessage message) {
    final user = message.role == AgentConversationRole.user;
    final system = message.role == AgentConversationRole.system;
    final run = message.planId == null ? null : _runs[message.planId];
    final content = user
        ? message.content
        : normalizeAgentReply(message.content);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          key: message.status == AgentConversationMessageStatus.failed
              ? const Key('agent_error_text')
              : Key('agent_message_${message.id}'),
          margin: const EdgeInsets.only(bottom: 24),
          padding: EdgeInsets.only(left: user ? 13 : 0),
          decoration: BoxDecoration(
            border: user
                ? const Border(
                    left: BorderSide(color: Color(0xFF4D4A45), width: 2),
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user ? 'YOU' : (system ? 'FILMLY · NOTICE' : 'FILMLY'),
                style: TextStyle(
                  color: system
                      ? const Color(0xFFA85C16)
                      : FilmlyPalette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.05,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                content,
                style: TextStyle(
                  color: system
                      ? const Color(0xFF754411)
                      : FilmlyPalette.textPrimary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              if (message.toolsUsed.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  'Sources: ${message.toolsUsed.map(_toolLabel).join(' · ')}',
                  style: const TextStyle(
                    color: FilmlyPalette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
              if (run != null) ...[const SizedBox(height: 14), _planCard(run)],
            ],
          ),
        ),
      ),
    );
  }

  Widget _thinkingIndicator() => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 720),
      child: Padding(
        padding: EdgeInsets.only(bottom: 22),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 9),
            Text(
              'FILMLY · reviewing your library',
              style: TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _planCard(MediaAgentRun run) {
    final plan = run.plan;
    final hasMatches = plan.preview.isNotEmpty;
    return Container(
      key: const Key('agent_plan_panel'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: Color(0xFF246BDE),
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${plan.preview.length} ITEMS',
                style: const TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _planStatusLabel(run.status),
            style: const TextStyle(
              color: FilmlyPalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.85,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plan.description,
            style: const TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 12,
            ),
          ),
          if (hasMatches) ...[
            const SizedBox(height: 11),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F5F2),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                children: plan.preview
                    .take(4)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${item.title} · ${item.detail}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FilmlyPalette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          const SizedBox(height: 13),
          _planAction(run, hasMatches: hasMatches),
        ],
      ),
    );
  }

  Widget _planAction(MediaAgentRun run, {required bool hasMatches}) {
    if (!hasMatches && run.status == MediaAgentRunStatus.planned) {
      return const Text(
        'No local matches yet. Nothing can change until this plan has scope.',
        style: TextStyle(color: FilmlyPalette.textMuted, fontSize: 12),
      );
    }
    return switch (run.status) {
      MediaAgentRunStatus.planned => FilmlyGlassButton(
        key: const Key('agent_confirm_plan_button'),
        label: 'Review & confirm',
        icon: Icons.check_circle_outline_rounded,
        accent: true,
        onTap: () => _confirmPlan(run),
      ),
      MediaAgentRunStatus.confirmed => FilmlyGlassButton(
        key: const Key('agent_execute_plan_button'),
        label: 'Execute plan',
        icon: Icons.play_arrow_rounded,
        accent: true,
        onTap: () => _executePlan(run),
      ),
      MediaAgentRunStatus.succeeded => Row(
        children: [
          const Text(
            'Completed',
            style: TextStyle(
              color: Color(0xFF26733F),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          FilmlyGlassButton(
            label: 'Undo',
            icon: Icons.undo_rounded,
            onTap: () => _undoRun(run),
          ),
        ],
      ),
      MediaAgentRunStatus.undone => const Text(
        'Undone',
        style: TextStyle(color: FilmlyPalette.textMuted, fontSize: 12),
      ),
      MediaAgentRunStatus.running => const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Working…', style: TextStyle(fontSize: 12)),
        ],
      ),
      MediaAgentRunStatus.failed => Text(
        run.error?.isNotEmpty == true
            ? run.error!
            : 'The plan did not complete.',
        style: const TextStyle(color: Color(0xFF9A3D21), fontSize: 12),
      ),
    };
  }

  Widget _composer() => Container(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
    decoration: const BoxDecoration(color: Color(0xFFF6F5F2)),
    child: Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(13, 7, 8, 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDFC),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE5E2DC)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('agent_request_input'),
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Ask about your library or describe a task…',
                    hintStyle: TextStyle(color: FilmlyPalette.textMuted),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilmlyGlassButton(
                key: const Key('agent_gemini_plan_button'),
                label: 'Send',
                icon: Icons.arrow_upward_rounded,
                accent: true,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                onTap: _thinking ? null : () => _sendMessage(),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _errorPanel() => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(28, 0, 28, 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEB),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      _error!,
      style: const TextStyle(color: Color(0xFF8B1E17), fontSize: 12),
    ),
  );

  void _openConversationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: _conversationRail(sheet: true),
          ),
        ),
      ),
    );
  }

  String _sectionFor(AgentConversation conversation) {
    if (conversation.isPinned) return 'Pinned';
    final now = DateTime.now();
    final updated = conversation.updatedAt.toLocal();
    if (DateUtils.isSameDay(now, updated)) return 'Today';
    if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), updated)) {
      return 'Yesterday';
    }
    if (now.difference(updated).inDays < 7) return 'Previous 7 days';
    return 'Earlier';
  }

  String _relativeTime(DateTime value) {
    final delta = DateTime.now().difference(value.toLocal());
    if (delta.inMinutes < 1) return 'updated just now';
    if (delta.inHours < 1) return 'updated ${delta.inMinutes} min ago';
    if (delta.inDays < 1) return 'updated ${delta.inHours} hr ago';
    return 'updated ${delta.inDays} days ago';
  }

  String _planStatusLabel(MediaAgentRunStatus status) => switch (status) {
    MediaAgentRunStatus.planned => 'PLAN · REVIEW BEFORE EXECUTION',
    MediaAgentRunStatus.confirmed => 'CONFIRMED · READY TO EXECUTE',
    MediaAgentRunStatus.running => 'RUNNING',
    MediaAgentRunStatus.succeeded => 'COMPLETED',
    MediaAgentRunStatus.failed => 'FAILED',
    MediaAgentRunStatus.undone => 'UNDONE',
  };

  String _toolLabel(String tool) => tool.replaceAll('_', ' ');
}

enum _ConversationAction { rename, pin, unpin, archive, delete }
