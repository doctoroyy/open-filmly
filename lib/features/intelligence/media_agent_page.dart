import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/intelligence/agent_models.dart';
import '../../providers/intelligence_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../widgets/media_command_palette.dart';

/// Gemini may use lightweight Markdown even when the conversation surface is
/// intentionally editorial rather than a Markdown document. Preserve the
/// content while removing the formatting markers that would otherwise render
/// as visual noise in a compact Agent reply.
String normalizeAgentReply(String value) {
  return value
      .replaceAll('\r\n', '\n')
      .replaceAll(
        RegExp(r'^[ \t]{0,3}#{1,6}[ \t]+', multiLine: true),
        '',
      )
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .trim();
}

class ChatUiMessage {
  ChatUiMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.plan,
    this.run,
    this.toolsUsed = const [],
  });

  final String id;
  final bool isUser;
  final String text;
  MediaAgentPlan? plan;
  MediaAgentRun? run;
  final List<String> toolsUsed;
}

class MediaAgentPage extends ConsumerStatefulWidget {
  const MediaAgentPage({super.key, this.initialPrompt});

  /// A command-palette query can be continued here when a conversation or a
  /// confirmation flow is more appropriate than a direct result jump.
  final String? initialPrompt;

  @override
  ConsumerState<MediaAgentPage> createState() => _MediaAgentPageState();
}

class _MediaAgentPageState extends ConsumerState<MediaAgentPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatUiMessage> _messages = [];

  bool _thinking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prompt = widget.initialPrompt?.trim();
    if (prompt?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendMessage(prompt));
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? textOverride]) async {
    final text = (textOverride ?? _inputController.text).trim();
    if (text.isEmpty || _thinking) return;

    if (textOverride == null) {
      _inputController.clear();
    }

    final userMsg = ChatUiMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}-user',
      isUser: true,
      text: text,
    );

    setState(() {
      _messages.add(userMsg);
      _thinking = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final engine = await ref.read(conversationalAgentEngineProvider.future);
      if (engine == null) {
        throw StateError('Gemini API Key 尚未配置');
      }

      final result = await engine.sendUserMessage(text);
      final agentMsg = ChatUiMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}-agent',
        isUser: false,
        text: result.replyText,
        plan: result.plan,
        toolsUsed: result.toolsUsed,
      );

      if (mounted) {
        setState(() {
          _messages.add(agentMsg);
        });
        _scrollToBottom();
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = '$err';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _thinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _confirmPlan(ChatUiMessage msg) async {
    final plan = msg.plan;
    if (plan == null) return;
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final run = await service.confirm(plan.id);
      if (mounted) {
        setState(() {
          msg.run = run;
        });
        _scrollToBottom();
      }
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    }
  }

  Future<void> _executePlan(ChatUiMessage msg) async {
    final run = msg.run;
    if (run == null) return;
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final result = await service.execute(run.id);
      if (mounted) {
        setState(() {
          msg.run = result;
        });
        _scrollToBottom();
      }
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    }
  }

  Future<void> _undoRun(ChatUiMessage msg) async {
    final run = msg.run;
    if (run == null) return;
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final result = await service.undo(run.id);
      if (mounted) {
        setState(() {
          msg.run = result;
        });
      }
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: _messages.isEmpty
                      ? _welcomePanel()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                          itemCount: _messages.length + (_thinking ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return _buildThinkingIndicator();
                            }
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
                ),
                if (_error != null) _errorPanel(),
                _composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
      child: Row(
        children: [
          FilmlyIconButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => context.canPop() ? context.pop() : context.go('/me'),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Agent',
                  style: TextStyle(
                    fontSize: 22,
                    letterSpacing: -0.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Plan first. Confirm before anything changes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: FilmlyPalette.textMuted,
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

  Widget _welcomePanel() {
    return Center(
      child: SingleChildScrollView(
        key: const Key('agent_workbench_welcome'),
        padding: const EdgeInsets.fromLTRB(30, 16, 30, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your library,\nwith intent.',
                style: TextStyle(
                  color: FilmlyPalette.textPrimary,
                  fontSize: 42,
                  height: 1.02,
                  letterSpacing: -1.7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Use this space for a conversation, a review, or a safe library task. For a quick scene or title, use Search instead.',
                style: TextStyle(
                  color: FilmlyPalette.textSecondary,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _starterPrompt('分析我的影视库健康度'),
                  _starterPrompt('查找重复媒体文件'),
                  _starterPrompt('建立科幻电影智能合集'),
                  _starterPrompt('给缺字幕的片子生成计划'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _starterPrompt(String text) {
    return InkWell(
      onTap: _thinking ? null : () => _sendMessage(text),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FilmlyPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FilmlyPalette.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_outward_rounded,
              color: FilmlyPalette.textMuted,
              size: 16,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: FilmlyPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPanel() {
    return Container(
      key: const Key('agent_error_text'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFFB42318),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFF8B1E17), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FilmlyPalette.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 5),
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
                hintText: 'Ask about your library, or describe a task…',
                hintStyle: TextStyle(color: FilmlyPalette.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
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
    );
  }

  Widget _buildThinkingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'OPEN FILMLY · Reviewing your library…',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: FilmlyPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatUiMessage msg) {
    final isUser = msg.isUser;
    final displayText = isUser ? msg.text : normalizeAgentReply(msg.text);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: Key('agent_message_${msg.id}'),
        margin: const EdgeInsets.symmetric(vertical: 12),
        constraints: const BoxConstraints(maxWidth: 620),
        padding: EdgeInsets.only(left: isUser ? 14 : 0),
        decoration: BoxDecoration(
          border: isUser
              ? const Border(
                  left: BorderSide(
                    color: FilmlyPalette.textSecondary,
                    width: 2,
                  ),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser ? 'YOU' : 'OPEN FILMLY',
              style: const TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayText,
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            if (msg.toolsUsed.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Consulted local tools: ${msg.toolsUsed.map(_toolLabel).join(' · ')}',
                style: const TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
            if (msg.plan != null) ...[
              const SizedBox(height: 14),
              _buildActionCard(msg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(ChatUiMessage msg) {
    final plan = msg.plan!;
    final run = msg.run;
    final hasMatches = plan.preview.isNotEmpty;
    return FilmlyGlassPanel(
      key: const Key('agent_plan_panel'),
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: FilmlyPalette.accent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (hasMatches)
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
          const SizedBox(height: 7),
          const Text(
            'PLAN · REVIEW BEFORE EXECUTION',
            style: TextStyle(
              color: FilmlyPalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.75,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plan.description,
            style: const TextStyle(
              fontSize: 12,
              color: FilmlyPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (hasMatches)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: Container(
                decoration: BoxDecoration(
                  color: FilmlyPalette.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plan.preview.take(5).length,
                  itemBuilder: (context, idx) {
                    final item = plan.preview[idx];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FilmlyPalette.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FilmlyPalette.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          if (!hasMatches) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('agent_empty_plan_notice'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FilmlyPalette.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 16,
                    color: FilmlyPalette.textMuted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No matches in this library. Nothing will change; try a broader rule or refresh metadata.',
                      style: TextStyle(
                        color: FilmlyPalette.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (run == null && !hasMatches)
            const Text(
              'Nothing to confirm until this plan has matches.',
              style: TextStyle(color: FilmlyPalette.textMuted, fontSize: 12),
            )
          else if (run == null)
            FilmlyGlassButton(
              key: const Key('agent_confirm_plan_button'),
              label: 'Review & confirm',
              icon: Icons.check_circle_outline_rounded,
              accent: true,
              onTap: () => _confirmPlan(msg),
            )
          else if (run.status == MediaAgentRunStatus.confirmed)
            FilmlyGlassButton(
              key: const Key('agent_execute_plan_button'),
              label: 'Execute plan',
              icon: Icons.play_arrow_rounded,
              accent: true,
              onTap: () => _executePlan(msg),
            )
          else if (run.status == MediaAgentRunStatus.succeeded)
            Row(
              children: [
                const Text(
                  '已完成',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                FilmlyGlassButton(
                  label: '撤销',
                  icon: Icons.undo_rounded,
                  onTap: () => _undoRun(msg),
                ),
              ],
            )
          else if (run.status == MediaAgentRunStatus.undone)
            const Text(
              '已撤销',
              style: TextStyle(color: FilmlyPalette.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  String _toolLabel(String tool) => tool.replaceAll('_', ' ');
}
