import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/intelligence/agent_models.dart';
import '../../providers/intelligence_providers.dart';
import '../../widgets/filmly_design.dart';

class MediaAgentPage extends ConsumerStatefulWidget {
  const MediaAgentPage({super.key});

  @override
  ConsumerState<MediaAgentPage> createState() => _MediaAgentPageState();
}

class _MediaAgentPageState extends ConsumerState<MediaAgentPage> {
  final _query = TextEditingController();
  final _name = TextEditingController();
  MediaAgentOperation _operation = MediaAgentOperation.listUnwatched;
  MediaAgentPlan? _plan;
  MediaAgentRun? _run;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _makePlan() async {
    final service = await ref.read(mediaAgentServiceProvider.future);
    setState(() {
      _working = true;
      _error = null;
      _run = null;
    });
    try {
      final plan = await service.plan(
        _operation,
        query: _query.text,
        collectionName: _name.text,
      );
      if (mounted) setState(() => _plan = plan);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirm() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _working = true);
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final run = await service.confirm(plan.id);
      if (mounted) setState(() => _run = run);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _execute() async {
    final run = _run;
    if (run == null) return;
    setState(() => _working = true);
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final result = await service.execute(run.id);
      if (mounted) setState(() => _run = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _undo() async {
    final run = _run;
    if (run == null) return;
    setState(() => _working = true);
    try {
      final service = await ref.read(mediaAgentServiceProvider.future);
      final result = await service.undo(run.id);
      if (mounted) setState(() => _run = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
          children: [
            Row(
              children: [
                FilmlyIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/me'),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Media Agent',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '先理解请求，再展示预览；只有确认后才执行。删除、移动和重命名默认关闭。',
              style: TextStyle(color: FilmlyPalette.textMuted, height: 1.45),
            ),
            const SizedBox(height: 20),
            FilmlyGlassPanel(
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<MediaAgentOperation>(
                    initialValue: _operation,
                    decoration: const InputDecoration(labelText: '操作'),
                    items: [
                      for (final operation in MediaAgentOperation.values)
                        DropdownMenuItem(
                          value: operation,
                          child: Text(operation.label),
                        ),
                    ],
                    onChanged: _working
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _operation = value);
                            }
                          },
                  ),
                  if (_operation == MediaAgentOperation.smartCollection) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: '合集名称'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _query,
                      decoration: const InputDecoration(labelText: '筛选主题/关键词'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilmlyGlassButton(
                    label: _working ? '处理中…' : '生成预览',
                    icon: _working ? null : Icons.visibility_outlined,
                    leading: _working
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _working ? null : _makePlan,
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_plan != null) ...[const SizedBox(height: 18), _planPanel()],
            if (_run != null) ...[const SizedBox(height: 14), _runPanel()],
          ],
        ),
      ),
    );
  }

  Widget _planPanel() {
    final plan = _plan!;
    return FilmlyGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(plan.description),
          const SizedBox(height: 12),
          if (plan.preview.isEmpty)
            const Text(
              '没有符合条件的媒体。',
              style: TextStyle(color: FilmlyPalette.textMuted),
            )
          else
            for (final item in plan.preview.take(12))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.movie_outlined,
                  color: FilmlyPalette.accent,
                ),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          if (plan.preview.length > 12)
            Text(
              '还有 ${plan.preview.length - 12} 项未展开',
              style: const TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 12),
          FilmlyGlassButton(
            label: '确认这个计划',
            icon: Icons.check_circle_outline_rounded,
            onTap: _working || _run != null ? null : _confirm,
          ),
        ],
      ),
    );
  }

  Widget _runPanel() {
    final run = _run!;
    return FilmlyGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '执行状态：${_statusLabel(run.status)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (run.error != null) ...[
            const SizedBox(height: 8),
            Text(run.error!, style: const TextStyle(color: Colors.red)),
          ],
          if (run.status == MediaAgentRunStatus.confirmed) ...[
            const SizedBox(height: 12),
            FilmlyGlassButton(
              label: '执行计划',
              icon: Icons.play_arrow_rounded,
              onTap: _working ? null : _execute,
            ),
          ],
          if (run.status == MediaAgentRunStatus.succeeded) ...[
            const SizedBox(height: 12),
            Text(
              run.result.toString(),
              style: const TextStyle(color: FilmlyPalette.textMuted),
            ),
            const SizedBox(height: 12),
            FilmlyGlassButton(
              label: '撤销本次结果',
              icon: Icons.undo_rounded,
              onTap: _working ? null : _undo,
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(MediaAgentRunStatus status) => switch (status) {
    MediaAgentRunStatus.planned => '待确认',
    MediaAgentRunStatus.confirmed => '已确认',
    MediaAgentRunStatus.running => '执行中',
    MediaAgentRunStatus.succeeded => '已完成',
    MediaAgentRunStatus.failed => '失败',
    MediaAgentRunStatus.undone => '已撤销',
  };
}
