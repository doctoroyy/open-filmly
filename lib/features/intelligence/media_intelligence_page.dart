import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/intelligence_providers.dart';
import '../../services/intelligence/library_intelligence_indexer.dart';
import '../../widgets/filmly_design.dart';

/// Control surface for the Personal Media Intelligence Layer.
/// Indexes local subtitle sidecars into transcripts, scenes, and offline
/// embeddings so Ask Filmly / Companion can understand the library without a
/// cloud ASR worker.
class MediaIntelligencePage extends ConsumerStatefulWidget {
  const MediaIntelligencePage({super.key});

  @override
  ConsumerState<MediaIntelligencePage> createState() =>
      _MediaIntelligencePageState();
}

class _MediaIntelligencePageState extends ConsumerState<MediaIntelligencePage> {
  Map<String, int>? _counts;
  LibraryIndexProgress? _lastRun;
  bool _loading = true;
  bool _indexing = false;
  String? _error;
  String _progressLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final counts = await ref
          .read(libraryIntelligenceIndexerProvider)
          .statusCounts();
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _indexLibrary() async {
    if (_indexing) return;
    setState(() {
      _indexing = true;
      _error = null;
      _progressLabel = '准备索引…';
    });
    try {
      final progress = await ref
          .read(libraryIntelligenceIndexerProvider)
          .indexLibrary(
            limit: 500,
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _progressLabel = total == 0
                    ? '没有可索引媒体'
                    : '正在索引 $done / $total';
              });
            },
          );
      if (!mounted) return;
      setState(() {
        _lastRun = progress;
        _indexing = false;
        _progressLabel = '';
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _indexing = false;
        _progressLabel = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
              children: [
                Row(
                  children: [
                    FilmlyIconButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Media Intelligence',
                        style: TextStyle(
                          color: FilmlyPalette.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loading || _indexing ? null : _refresh,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '把本地影视库升级成可搜索的私人媒体图谱：导入字幕旁车、建立场景分段和离线语义索引。不需要云端，也不会改动你的媒体文件。',
                  style: TextStyle(
                    color: FilmlyPalette.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statCard(
                        'Library items',
                        '${counts?['libraryItems'] ?? 0}',
                      ),
                      _statCard(
                        'Intelligence assets',
                        '${counts?['intelligenceAssets'] ?? 0}',
                      ),
                      _statCard(
                        'With transcripts',
                        '${counts?['assetsWithTranscripts'] ?? 0}',
                      ),
                      _statCard(
                        'Linked to media',
                        '${counts?['linkedAssets'] ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilmlyGlassPanel(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Build the understanding layer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. 扫描本地媒体并注册稳定资产身份\n'
                          '2. 自动导入同目录 .srt / .vtt 字幕旁车\n'
                          '3. 生成场景分段（含片头/片尾启发式）\n'
                          '4. 写入离线语义向量，供 Ask Filmly 与 Companion 使用',
                          style: TextStyle(
                            color: FilmlyPalette.textSecondary,
                            height: 1.55,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            FilmlyGlassButton(
                              key: const Key('intelligence_index_library'),
                              label: _indexing ? 'Indexing…' : 'Index library',
                              icon: Icons.auto_awesome_motion_rounded,
                              accent: true,
                              onTap: _indexing ? null : _indexLibrary,
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () => context.push('/ask'),
                              child: const Text('Open Ask Filmly'),
                            ),
                            TextButton(
                              onPressed: () => context.push('/agent'),
                              child: const Text('Open Conversations'),
                            ),
                            TextButton(
                              onPressed: () => context.push('/collections'),
                              child: const Text('Smart Collections'),
                            ),
                          ],
                        ),
                        if (_progressLabel.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _progressLabel,
                            style: const TextStyle(
                              color: FilmlyPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (_lastRun != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Last run: scanned ${_lastRun!.scanned}, '
                            'indexed ${_lastRun!.indexed}, '
                            'with transcripts ${_lastRun!.withTranscripts}, '
                            'skipped ${_lastRun!.skipped}'
                            '${_lastRun!.errors.isEmpty ? '' : ', errors ${_lastRun!.errors.length}'}',
                            style: const TextStyle(
                              color: FilmlyPalette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (_lastRun!.errors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _lastRun!.errors.take(3).join('\n'),
                                style: const TextStyle(
                                  color: Color(0xFF9A3D21),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF9A3D21)),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return SizedBox(
      width: 180,
      child: FilmlyGlassPanel(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
