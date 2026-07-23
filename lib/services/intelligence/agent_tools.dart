import 'dart:io';

import '../../data/models/media.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/playback_progress_repository.dart';
import '../playback/external_subtitle_finder.dart';
import 'library_intelligence_indexer.dart';
import 'semantic_search_service.dart';

/// Function calling declarations and local tool dispatcher for Gemini Agent.
class AgentTools {
  static const List<Map<String, dynamic>> declarations = [
    {
      'name': 'search_media',
      'description': '在本地/网络影视库中，按关键词、风格类型、年份区间、最低评分等条件组合检索影片',
      'parameters': {
        'type': 'object',
        'properties': {
          'searchTerm': {'type': 'string', 'description': '搜索关键词'},
          'genre': {'type': 'string', 'description': '电影/电视剧类型风格，如 科幻、悬疑、动作、动画'},
          'minYear': {'type': 'integer', 'description': '最早上映年份，如 2010'},
          'maxYear': {'type': 'integer', 'description': '最晚上映年份，如 2024'},
          'minRating': {'type': 'number', 'description': '最低评分(1-10)'},
          'unwatchedOnly': {'type': 'boolean', 'description': '是否只看未播放过的内容'},
        },
      },
    },
    {
      'name': 'get_library_stats',
      'description': '获取整个媒体库的统计概览（包括总数量、电影/剧集分类数量、未观看统计、收藏数量等）',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'analyze_viewing_habits',
      'description': '分析用户的影视观看偏好、最常看类型与播放进度完成情况',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'inspect_metadata_health',
      'description': '诊断媒体库健康度（如缺失海报/简介/评分的视听资源）',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'inspect_media_issues',
      'description': '检查媒体库潜在问题（如重复文件、疑似低画质文件、无字幕本地文件）',
      'parameters': {
        'type': 'object',
        'properties': {
          'issueType': {
            'type': 'string',
            'enum': ['duplicates', 'lowQuality', 'missingSubtitles'],
            'description': '检查问题类型',
          },
        },
        'required': ['issueType'],
      },
    },
    {
      'name': 'create_smart_collection',
      'description': '生成创建智能影视合集的方案',
      'parameters': {
        'type': 'object',
        'properties': {
          'collectionName': {'type': 'string', 'description': '合集名称'},
          'query': {'type': 'string', 'description': '合集规则关键词'},
        },
        'required': ['collectionName'],
      },
    },
    {
      'name': 'batch_generate_subtitles',
      'description': '生成批量对缺失字幕的视频补充字幕的方案',
      'parameters': {
        'type': 'object',
        'properties': {
          'filterQuery': {'type': 'string', 'description': '要处理的视频的关键词'},
        },
      },
    },
    {
      'name': 'search_dialogue_scenes',
      'description': '在本地已索引的字幕/对白时间轴中搜索场景，并返回可跳转的时间点',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '场景、对白、人物或主题描述',
          },
        },
        'required': ['query'],
      },
    },
    {
      'name': 'get_intelligence_status',
      'description': '查询 Media Intelligence 索引状态，解释为何对白/场景搜索可能为空',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
  ];

  static Future<Map<String, dynamic>> execute({
    required String name,
    required Map<String, dynamic> arguments,
    required MediaRepository mediaRepository,
    required PlaybackProgressRepository progressRepository,
    SemanticSearchService? semanticSearch,
    LibraryIntelligenceIndexer? intelligenceIndexer,
  }) async {
    switch (name) {
      case 'search_media':
        final searchTerm = arguments['searchTerm']?.toString();
        final genre = arguments['genre']?.toString();
        final minYear = arguments['minYear'] is int
            ? arguments['minYear'] as int
            : int.tryParse(arguments['minYear']?.toString() ?? '');
        final maxYear = arguments['maxYear'] is int
            ? arguments['maxYear'] as int
            : int.tryParse(arguments['maxYear']?.toString() ?? '');
        final minRating = arguments['minRating'] is num
            ? (arguments['minRating'] as num).toDouble()
            : double.tryParse(arguments['minRating']?.toString() ?? '');
        final unwatchedOnly = arguments['unwatchedOnly'] == true;

        final results = await mediaRepository.queryAdvanced(
          searchTerm: searchTerm,
          genres: genre != null && genre.isNotEmpty ? [genre] : null,
          minYear: minYear,
          maxYear: maxYear,
          minRating: minRating,
        );

        final items = <Map<String, dynamic>>[];
        for (final m in results.take(30)) {
          final progress = await progressRepository.getByMediaId(m.id);
          if (unwatchedOnly &&
              progress != null &&
              progress.position > Duration.zero) {
            continue;
          }
          items.add({
            'id': m.id,
            'title': m.title,
            'year': m.year,
            'type': m.type.name,
            'rating': m.rating,
            'genres': m.genres,
            'isFavorite': m.isFavorite,
            'hasWatched':
                progress != null && progress.position > Duration.zero,
          });
        }
        return {
          'count': items.length,
          'media': items,
        };

      case 'get_library_stats':
        final counts = await mediaRepository.countByType();
        final favorites = await mediaRepository.getFavorites();
        final all = await mediaRepository.browse(deduplicateShows: false);
        var watchedCount = 0;
        for (final m in all) {
          final progress = await progressRepository.getByMediaId(m.id);
          if (progress != null && progress.position > Duration.zero) {
            watchedCount++;
          }
        }
        return {
          'totalCount': all.length,
          'movieCount': counts[MediaType.movie] ?? 0,
          'tvCount': counts[MediaType.tv] ?? 0,
          'favoriteCount': favorites.length,
          'watchedCount': watchedCount,
          'unwatchedCount': (all.length - watchedCount).clamp(0, all.length),
        };

      case 'analyze_viewing_habits':
        final all = await mediaRepository.browse(deduplicateShows: false);
        final genreMap = <String, int>{};
        var watchedCount = 0;

        for (final m in all) {
          for (final g in m.genres) {
            genreMap[g] = (genreMap[g] ?? 0) + 1;
          }
          final progress = await progressRepository.getByMediaId(m.id);
          if (progress != null && progress.position > Duration.zero) {
            watchedCount++;
          }
        }
        final sortedGenres = genreMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return {
          'totalMedia': all.length,
          'watchedMedia': watchedCount,
          'topGenres': sortedGenres.take(5).map((e) => e.key).toList(),
        };

      case 'inspect_metadata_health':
        final all = await mediaRepository.browse(deduplicateShows: false);
        var missingPoster = 0;
        var missingRating = 0;
        var missingOverview = 0;
        final samples = <Map<String, dynamic>>[];
        for (final m in all) {
          final issues = <String>[];
          if (m.posterPath == null || m.posterPath!.isEmpty) {
            missingPoster++;
            issues.add('poster');
          }
          if (m.rating == null || m.rating!.isEmpty) {
            missingRating++;
            issues.add('rating');
          }
          if (m.overview == null || m.overview!.trim().isEmpty) {
            missingOverview++;
            issues.add('overview');
          }
          if (issues.isNotEmpty && samples.length < 8) {
            samples.add({
              'id': m.id,
              'title': m.title,
              'issues': issues,
            });
          }
        }
        return {
          'totalChecked': all.length,
          'missingPosterCount': missingPoster,
          'missingRatingCount': missingRating,
          'missingOverviewCount': missingOverview,
          'samples': samples,
        };

      case 'inspect_media_issues':
        final issueType = arguments['issueType']?.toString() ?? 'duplicates';
        final all = await mediaRepository.browse(deduplicateShows: false);
        final matches = <Map<String, dynamic>>[];

        if (issueType == 'duplicates') {
          final groups = <String, List<Media>>{};
          for (final item in all) {
            final hash = item.fileHash?.trim().toLowerCase();
            if (hash != null && hash.isNotEmpty) {
              groups.putIfAbsent(hash, () => []).add(item);
            }
          }
          for (final group in groups.values.where((g) => g.length > 1)) {
            for (final m in group) {
              matches.add({
                'id': m.id,
                'title': m.title,
                'path': m.path,
                'issue': '重复文件指纹',
              });
            }
          }
        } else if (issueType == 'lowQuality') {
          for (final item in all) {
            final val = '${item.title} ${item.path}'.toLowerCase();
            if (RegExp(r'(^|[ ._\-])(144|240|360|480|576|720)p($|[ ._\-])')
                    .hasMatch(val) ||
                val.contains('sd')) {
              matches.add({
                'id': item.id,
                'title': item.title,
                'path': item.path,
                'issue': '分辨率较低',
              });
            }
          }
        } else if (issueType == 'missingSubtitles') {
          for (final item in all) {
            final path = _localPath(item);
            if (path == null) continue;
            final file = File(path);
            if (!await file.exists()) continue;
            final sidecars = await ExternalSubtitleFinder.findFor(path);
            if (sidecars.isEmpty) {
              matches.add({
                'id': item.id,
                'title': item.title,
                'path': path,
                'issue': '同目录无字幕旁车',
              });
            }
          }
        }
        return {
          'issueType': issueType,
          'foundCount': matches.length,
          'items': matches.take(30).toList(),
        };

      case 'create_smart_collection':
      case 'batch_generate_subtitles':
        return {'status': 'ready_for_plan_generation', 'args': arguments};

      case 'search_dialogue_scenes':
        final query = arguments['query']?.toString().trim() ?? '';
        if (query.isEmpty) {
          return {'error': 'query is required'};
        }
        if (semanticSearch == null) {
          return {
            'error': 'semantic search is not available',
            'hint': '在 Media Intelligence 中先建立字幕索引',
          };
        }
        final results = await semanticSearch.search(query, limit: 12);
        final scenes = [
          for (final item in results)
            if (item.isScene || item.startMs != null)
              {
                'title': item.title,
                'year': item.year,
                'mediaId': item.mediaId,
                'startMs': item.startMs,
                'endMs': item.endMs,
                'snippet': item.snippet,
                'reason': item.reason,
                'score': item.score,
                'playable': item.isScene,
              },
        ];
        return {
          'count': scenes.length,
          'scenes': scenes,
          if (scenes.isEmpty)
            'hint': '无时间轴命中。请确认已 Index library 且存在字幕旁车或 ASR 结果。',
        };

      case 'get_intelligence_status':
        final indexer = intelligenceIndexer;
        if (indexer == null) {
          return {
            'error': 'intelligence indexer is not available',
            'hint': '打开 Media Intelligence 页面建立索引',
          };
        }
        final counts = await indexer.statusCounts();
        return {
          ...counts,
          'hint': (counts['assetsWithTranscripts'] ?? 0) == 0
              ? '尚未发现对白索引：放入 .srt/.vtt 旁车后点击 Index library。'
              : '已有部分对白索引，可在 Ask Filmly / 对话中搜索场景。',
        };

      default:
        return {'error': 'Unknown tool: $name'};
    }
  }

  static String? _localPath(Media item) {
    final raw = (item.fullPath?.trim().isNotEmpty == true)
        ? item.fullPath!.trim()
        : item.path.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri?.scheme == 'file') return uri!.toFilePath();
    if (uri?.hasScheme == true) return null;
    return raw;
  }
}
