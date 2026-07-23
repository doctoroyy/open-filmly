import '../../data/intelligence/agent_models.dart';
import 'agent_planner.dart';

/// Offline, deterministic planner for common Chinese/English library tasks.
/// Used when Gemini is unavailable so Media Agent remains useful on a real
/// private library without a cloud key.
class LocalRuleAgentPlanner implements MediaAgentPlanner {
  const LocalRuleAgentPlanner();

  @override
  Future<AgentIntent> plan(String request) async {
    final intent = tryMatch(request);
    if (intent == null) {
      throw const AgentPlannerException(
        '无法在离线规则中识别该请求。可配置 Gemini API Key 处理更自由的自然语言，或换一种说法：影视库健康度 / 查重复 / 低画质 / 未观看 / 智能合集 / 生成字幕',
      );
    }
    return intent;
  }

  /// Returns null when the request should be handled as a pure tool answer
  /// (stats/search) or is not recognized as a plan operation.
  AgentIntent? tryMatch(String request) {
    final text = request.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    // Destructive intent → never map to mutation; report only.
    if (RegExp(r'删除|移除|清空|rm\b|delete|remove\s+files?').hasMatch(lower)) {
      if (RegExp(r'重复|duplicate').hasMatch(lower)) {
        return const AgentIntent(
          operation: MediaAgentOperation.findDuplicates,
          reasoning: '拒绝静默删除；仅生成重复报告',
        );
      }
      return const AgentIntent(
        operation: MediaAgentOperation.libraryReport,
        reasoning: '拒绝破坏性请求；改为库统计报告',
      );
    }

    if (RegExp(r'字幕|subtitle|asr|whisper').hasMatch(lower) &&
        RegExp(r'生成|批量|补|generate|batch').hasMatch(lower)) {
      final query = _extractQuery(
        text,
        strip: RegExp(r'字幕|subtitle|生成|批量|补全|补|generate|batch|for|的|一下'),
      );
      return AgentIntent(
        operation: MediaAgentOperation.batchSubtitles,
        query: query,
        reasoning: 'offline:batchSubtitles',
      );
    }

    if (RegExp(r'重复|duplicate').hasMatch(lower)) {
      return const AgentIntent(
        operation: MediaAgentOperation.findDuplicates,
        reasoning: 'offline:findDuplicates',
      );
    }

    if (RegExp(r'低画质|低分辨率|480p|360p|720p|sd\b|low\s*quality').hasMatch(lower)) {
      return const AgentIntent(
        operation: MediaAgentOperation.inspectLowQuality,
        reasoning: 'offline:inspectLowQuality',
      );
    }

    if (RegExp(r'未观看|没看过|长期未看|unwatched|never\s*watched').hasMatch(lower) &&
        !RegExp(r'合集|collection').hasMatch(lower)) {
      return const AgentIntent(
        operation: MediaAgentOperation.listUnwatched,
        reasoning: 'offline:listUnwatched',
      );
    }

    if (RegExp(r'智能合集|合集|collection|playlist').hasMatch(lower) ||
        RegExp(r'建一个|创建.*片|今晚看|推荐.*片').hasMatch(lower)) {
      final nameMatch = RegExp(r'[「"“](.+?)[」"”]').firstMatch(text);
      final collectionName = nameMatch?.group(1)?.trim();
      final query = _extractQuery(
        text,
        strip: RegExp(
          r'智能合集|合集|collection|playlist|建一个|创建|帮我|生成|名叫|叫做|叫|一下|吧',
        ),
      );
      return AgentIntent(
        operation: MediaAgentOperation.smartCollection,
        query: query.isEmpty ? text : query,
        collectionName: collectionName,
        reasoning: 'offline:smartCollection',
      );
    }

    if (RegExp(r'健康度|库统计|全盘|overview|library\s*report|有多少').hasMatch(lower) &&
        !RegExp(r'缺字幕|无字幕|对白|场景').hasMatch(lower)) {
      return const AgentIntent(
        operation: MediaAgentOperation.libraryReport,
        reasoning: 'offline:libraryReport',
      );
    }

    return null;
  }

  /// Tool-oriented intents that answer immediately without a plan card.
  LocalToolIntent? tryToolIntent(String request) {
    final text = request.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    if (RegExp(r'索引|intelligence|为什么.*搜不到|字幕索引|ai\s*index').hasMatch(lower)) {
      return const LocalToolIntent(
        tool: 'get_intelligence_status',
        arguments: {},
      );
    }

    if (RegExp(r'缺字幕|无字幕|missing\s*subtitle').hasMatch(lower)) {
      return const LocalToolIntent(
        tool: 'inspect_media_issues',
        arguments: {'issueType': 'missingSubtitles'},
      );
    }

    if (RegExp(r'健康度|缺海报|缺评分|缺简介|metadata\s*health').hasMatch(lower)) {
      return const LocalToolIntent(
        tool: 'inspect_metadata_health',
        arguments: {},
      );
    }

    if (RegExp(r'统计|有多少|多少部|library\s*stats|overview').hasMatch(lower) &&
        !RegExp(r'合集|字幕').hasMatch(lower)) {
      return const LocalToolIntent(tool: 'get_library_stats', arguments: {});
    }

    if (RegExp(r'观看习惯|偏好|常看|viewing\s*habit').hasMatch(lower)) {
      return const LocalToolIntent(
        tool: 'analyze_viewing_habits',
        arguments: {},
      );
    }

    if (RegExp(r'对白|台词|场景|雨夜|哪一集|哪一段|dialogue|scene|timestamp').hasMatch(lower) ||
        (RegExp(r'找|搜索|search').hasMatch(lower) &&
            RegExp(r'说|讲|出现|片段').hasMatch(lower))) {
      final query = _extractQuery(
        text,
        strip: RegExp(
          r'对白|台词|场景|片段|找|搜索|一下|帮我|search|dialogue|scene|for|的|是|哪一集|哪一段',
        ),
      );
      if (query.isEmpty) return null;
      return LocalToolIntent(
        tool: 'search_dialogue_scenes',
        arguments: {'query': query},
      );
    }

    if (RegExp(r'找|搜索|search|有没有|看.*片').hasMatch(lower) &&
        !RegExp(r'合集|字幕|重复|健康').hasMatch(lower)) {
      final genre = _matchGenre(lower);
      final unwatched = RegExp(r'未观看|没看|unwatched').hasMatch(lower);
      final term = _extractQuery(
        text,
        strip: RegExp(
          r'找|搜索|一下|帮我|有没有|想看|推荐|未观看|没看过|没看|电影|剧|片|search|for|a|an|the|unwatched|genre',
        ),
      );
      return LocalToolIntent(
        tool: 'search_media',
        arguments: {
          if (term.isNotEmpty) 'searchTerm': term,
          if (genre != null) 'genre': genre,
          if (unwatched) 'unwatchedOnly': true,
        },
      );
    }

    return null;
  }

  String? _matchGenre(String lower) {
    const genres = <String, String>{
      '科幻': '科幻',
      '悬疑': '悬疑',
      '动作': '动作',
      '动画': '动画',
      '喜剧': '喜剧',
      '恐怖': '恐怖',
      '爱情': '爱情',
      '纪录片': '纪录',
      'scifi': 'Sci-Fi',
      'sci-fi': 'Sci-Fi',
      'comedy': 'Comedy',
      'horror': 'Horror',
      'action': 'Action',
      'drama': 'Drama',
    };
    for (final entry in genres.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _extractQuery(String text, {required RegExp strip}) {
    return text
        .replaceAll(strip, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class LocalToolIntent {
  const LocalToolIntent({required this.tool, required this.arguments});

  final String tool;
  final Map<String, dynamic> arguments;
}
