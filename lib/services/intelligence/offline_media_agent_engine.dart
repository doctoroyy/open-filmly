import '../../data/repositories/media_repository.dart';
import '../../data/repositories/playback_progress_repository.dart';
import 'agent_tools.dart';
import 'conversational_agent_engine.dart';
import 'library_intelligence_indexer.dart';
import 'local_rule_agent_planner.dart';
import 'media_agent_service.dart';
import 'semantic_search_service.dart';

/// Runs grounded Media Agent turns without Gemini: local rule planner + tools
/// + optional safe plan creation. Returns null when the request is outside the
/// offline allowlist (caller may escalate to a cloud engine).
class OfflineMediaAgentEngine {
  OfflineMediaAgentEngine({
    required this.mediaRepository,
    required this.progressRepository,
    required this.agentService,
    this.semanticSearch,
    this.intelligenceIndexer,
    this.planner = const LocalRuleAgentPlanner(),
  });

  final MediaRepository mediaRepository;
  final PlaybackProgressRepository progressRepository;
  final MediaAgentService agentService;
  final SemanticSearchService? semanticSearch;
  final LibraryIntelligenceIndexer? intelligenceIndexer;
  final LocalRuleAgentPlanner planner;

  Future<ConversationalTurnResult?> tryHandle(String userPrompt) async {
    final prompt = userPrompt.trim();
    if (prompt.isEmpty) return null;

    final toolIntent = planner.tryToolIntent(prompt);
    if (toolIntent != null) {
      final payload = await AgentTools.execute(
        name: toolIntent.tool,
        arguments: toolIntent.arguments,
        mediaRepository: mediaRepository,
        progressRepository: progressRepository,
        semanticSearch: semanticSearch,
        intelligenceIndexer: intelligenceIndexer,
      );
      return ConversationalTurnResult(
        replyText: _formatToolReply(toolIntent.tool, payload),
        toolsUsed: [toolIntent.tool],
      );
    }

    final planIntent = planner.tryMatch(prompt);
    if (planIntent == null) return null;

    final plan = await agentService.plan(
      planIntent.operation,
      query: planIntent.query,
      collectionName: planIntent.collectionName,
    );
    final previewLines = plan.preview
        .take(8)
        .map((item) => '· ${item.title}${item.detail.isEmpty ? '' : ' — ${item.detail}'}')
        .join('\n');
    final reply = StringBuffer()
      ..writeln('已根据本地规则生成可审核计划：**${plan.title}**')
      ..writeln(plan.description)
      ..writeln('影响范围 ${plan.preview.length} 项（预览最多 8 条）：')
      ..writeln(previewLines.isEmpty ? '· （无匹配项）' : previewLines)
      ..writeln()
      ..writeln('下一步：在计划卡片中「审核并确认」后才会执行；不会静默改动媒体文件。');
    return ConversationalTurnResult(
      replyText: reply.toString(),
      plan: plan,
      toolsUsed: ['local_rule_plan:${planIntent.operation.name}'],
    );
  }

  String _formatToolReply(String tool, Map<String, dynamic> payload) {
    if (payload['error'] != null) {
      final hint = payload['hint']?.toString();
      return [
        '工具 `$tool` 未能完成：${payload['error']}',
        if (hint != null && hint.isNotEmpty) hint,
      ].join('\n');
    }

    switch (tool) {
      case 'get_library_stats':
        return '本地影视库统计（真实库数据）：\n'
            '· 总计 ${payload['totalCount']} 项\n'
            '· 电影 ${payload['movieCount']} · 剧集 ${payload['tvCount']}\n'
            '· 收藏 ${payload['favoriteCount']}\n'
            '· 有播放记录 ${payload['watchedCount'] ?? '—'} · 未观看估算 ${payload['unwatchedCount'] ?? '—'}';
      case 'inspect_metadata_health':
        final samples = payload['samples'];
        final sampleText = samples is List && samples.isNotEmpty
            ? '\n样例：${samples.take(5).map((s) => s is Map ? s['title'] : s).join('、')}'
            : '';
        return '元数据健康度：\n'
            '· 检查 ${payload['totalChecked']} 项\n'
            '· 缺海报 ${payload['missingPosterCount']}\n'
            '· 缺评分 ${payload['missingRatingCount']}\n'
            '· 缺简介 ${payload['missingOverviewCount'] ?? 0}'
            '$sampleText';
      case 'inspect_media_issues':
        final items = payload['items'];
        final list = items is List
            ? items
                  .take(10)
                  .map((item) {
                    if (item is! Map) return '· $item';
                    return '· ${item['title'] ?? item['id']}（${item['issue'] ?? payload['issueType']}）';
                  })
                  .join('\n')
            : '';
        return '问题检查（${payload['issueType']}）：发现 ${payload['foundCount']} 项'
            '${list.isEmpty ? '' : '\n$list'}\n'
            '说明：以上仅为报告，不会删除或移动文件。';
      case 'search_media':
        final media = payload['media'];
        final list = media is List
            ? media
                  .take(12)
                  .map((item) {
                    if (item is! Map) return '· $item';
                    final year = item['year']?.toString() ?? '';
                    final watched = item['hasWatched'] == true ? '已看' : '未看';
                    return '· ${item['title']}${year.isEmpty ? '' : ' ($year)'} · $watched';
                  })
                  .join('\n')
            : '';
        return '检索到 ${payload['count']} 部相关作品：\n${list.isEmpty ? '· 无匹配' : list}';
      case 'search_dialogue_scenes':
        final scenes = payload['scenes'];
        if (scenes is! List || scenes.isEmpty) {
          return '对白/场景检索无结果。若刚导入字幕，请先在 Media Intelligence 中建立索引。';
        }
        final list = scenes
            .take(10)
            .map((item) {
              if (item is! Map) return '· $item';
              final start = item['startMs'];
              final time = start is int
                  ? _formatMs(start)
                  : (int.tryParse(start?.toString() ?? '') != null
                        ? _formatMs(int.parse(start.toString()))
                        : '—');
              return '· ${item['title']} @ $time — ${item['snippet'] ?? item['reason'] ?? ''}';
            })
            .join('\n');
        return '场景/对白匹配 ${payload['count']} 条：\n$list';
      case 'get_intelligence_status':
        return 'Media Intelligence 状态：\n'
            '· 库条目 ${payload['libraryItems']}\n'
            '· 智能资产 ${payload['intelligenceAssets']}\n'
            '· 已关联媒体 ${payload['linkedAssets']}\n'
            '· 有字幕/对白索引 ${payload['assetsWithTranscripts']}\n'
            '${payload['hint'] ?? '无对白结果时请先 Index library 或放入 .srt 旁车。'}';
      case 'analyze_viewing_habits':
        final genres = payload['topGenres'];
        final genreText = genres is List ? genres.join('、') : '—';
        return '观看习惯（基于本地进度与类型标签）：\n'
            '· 库内 ${payload['totalMedia']} · 有进度 ${payload['watchedMedia']}\n'
            '· 常见类型：$genreText';
      default:
        return '工具 `$tool` 结果：${payload.toString()}';
    }
  }

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
