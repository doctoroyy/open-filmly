import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/intelligence_providers.dart';
import '../../widgets/filmly_design.dart';
import '../../data/intelligence/watch_event_repository.dart';

class PersonalMemoryPage extends ConsumerWidget {
  const PersonalMemoryPage({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final location = await getSaveLocation(
      suggestedName: 'open-filmly-memory.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Open Filmly 观看记忆', extensions: ['json']),
      ],
      confirmButtonText: '导出',
    );
    final path = location?.path;
    if (path == null || path.isEmpty || !context.mounted) return;
    try {
      await File(path).writeAsString(
        await ref.read(personalMemoryServiceProvider).exportJson(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('观看记忆已导出')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败：$error')));
      }
    }
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空观看记忆？'),
        content: const Text('只会清空 AI 观看事件，不会删除媒体、收藏或播放进度。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(personalMemoryServiceProvider).clear();
    ref.invalidate(personalMemorySummaryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('观看记忆已清空')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(personalMemorySummaryProvider);
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('读取观看记忆失败：$error')),
          data: (value) => ListView(
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
                      'Personal Film Memory',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '导出',
                    onPressed: () => _export(context, ref),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '你的观看记忆默认只保存在本机，用来理解你看过什么、反复看过什么以及偏好的主题。',
                style: TextStyle(color: FilmlyPalette.textMuted, height: 1.45),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _stat('观看媒体', value.watchedAssets.toString()),
                  _stat('看完', value.completedAssets.toString()),
                  _stat('重复观看', value.repeatAssets.toString()),
                  _stat('事件', value.totalEvents.toString()),
                ],
              ),
              const SizedBox(height: 24),
              _section(
                title: '偏好主题',
                child: value.topicCounts.isEmpty
                    ? const Text('积累一些观看记录后，这里会出现你的主题偏好。')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in value.topicCounts.entries)
                            Chip(label: Text('${entry.key}  ${entry.value}')),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _section(
                title: '最近事件',
                child: value.recent.isEmpty
                    ? const Text('还没有观看记忆。')
                    : Column(
                        children: [
                          for (final item in value.recent)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _iconFor(item.kind),
                                color: FilmlyPalette.accent,
                              ),
                              title: Text(item.title),
                              subtitle: Text(
                                '${_labelFor(item.kind)} · ${_clock(item.positionMs)}',
                              ),
                              dense: true,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              FilmlyGlassButton(
                label: '清空观看记忆',
                icon: Icons.delete_outline_rounded,
                onTap: () => _clear(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: FilmlyPalette.textMuted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _section({required String title, required Widget child}) =>
      FilmlyGlassPanel(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  static IconData _iconFor(WatchEventKind kind) => switch (kind) {
    WatchEventKind.play => Icons.play_arrow_rounded,
    WatchEventKind.pause => Icons.pause_rounded,
    WatchEventKind.progress => Icons.timelapse_rounded,
    WatchEventKind.seek || WatchEventKind.skip => Icons.fast_forward_rounded,
    WatchEventKind.completed => Icons.check_circle_outline_rounded,
    WatchEventKind.repeat => Icons.replay_rounded,
    WatchEventKind.abandon => Icons.exit_to_app_rounded,
    WatchEventKind.favorite => Icons.favorite_border_rounded,
  };

  static String _labelFor(WatchEventKind kind) => switch (kind) {
    WatchEventKind.play => '开始播放',
    WatchEventKind.pause => '暂停',
    WatchEventKind.progress => '观看进度',
    WatchEventKind.seek => '跳转',
    WatchEventKind.skip => '快进/快退',
    WatchEventKind.completed => '看完',
    WatchEventKind.repeat => '重复观看',
    WatchEventKind.abandon => '离开',
    WatchEventKind.favorite => '收藏',
  };

  static String _clock(int milliseconds) {
    final value = Duration(milliseconds: milliseconds);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.inHours)}:${two(value.inMinutes.remainder(60))}:${two(value.inSeconds.remainder(60))}';
  }
}
