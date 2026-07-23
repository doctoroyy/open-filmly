import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/intelligence/agent_models.dart';
import '../../data/intelligence/agent_run_repository.dart';
import '../../data/intelligence/smart_collection_repository.dart';
import '../../data/models/media.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/playback_progress_repository.dart';
import 'agent_planner.dart';
import 'local_rule_agent_planner.dart';

typedef AgentSubtitleGenerator = Future<List<String>> Function(Media media);

/// Executes a deliberately small, safe set of local-media automations.
/// Every operation is persisted as a preview first and requires an explicit
/// confirmation before execution. Destructive file operations are not part of
/// this service.
class MediaAgentService {
  static const longUnwatchedDays = 90;

  MediaAgentService({
    required this.mediaRepository,
    required this.progressRepository,
    required this.runs,
    required this.collections,
    this.subtitleGenerator,
    this.planner,
  });

  final MediaRepository mediaRepository;
  final PlaybackProgressRepository progressRepository;
  final AgentRunRepository runs;
  final SmartCollectionRepository collections;
  final AgentSubtitleGenerator? subtitleGenerator;
  final MediaAgentPlanner? planner;

  Future<MediaAgentPlan> planFromRequest(String request) async {
    final agentPlanner = planner;
    if (agentPlanner == null) {
      // Offline fallback so common Chinese library jobs work without Gemini.
      final intent = await const LocalRuleAgentPlanner().plan(request);
      return plan(
        intent.operation,
        query: intent.query,
        collectionName: intent.collectionName,
      );
    }
    final intent = await agentPlanner.plan(request);
    return plan(
      intent.operation,
      query: intent.query,
      collectionName: intent.collectionName,
    );
  }

  Future<MediaAgentPlan> plan(
    MediaAgentOperation operation, {
    String query = '',
    String? collectionName,
  }) async {
    final media = await mediaRepository.browse(deduplicateShows: false);
    final candidates = switch (operation) {
      MediaAgentOperation.batchSubtitles =>
        media.where(_isSubtitleCandidate).toList(),
      MediaAgentOperation.findDuplicates => _duplicateCandidates(media),
      MediaAgentOperation.inspectLowQuality =>
        media.where(_isLowQuality).toList(),
      MediaAgentOperation.smartCollection => await _collectionCandidates(
        media,
        query,
      ),
      MediaAgentOperation.listUnwatched => await _unwatchedCandidates(media),
      MediaAgentOperation.customFilter => await _collectionCandidates(
        media,
        query,
      ),
      MediaAgentOperation.libraryReport => media,
    };
    final name = collectionName?.trim().isNotEmpty == true
        ? collectionName!.trim()
        : (query.trim().isEmpty ? '智能合集' : query.trim());
    final planId = '${DateTime.now().microsecondsSinceEpoch}-${operation.name}';
    final preview = candidates
        .take(50)
        .map(
          (item) => AgentPreviewItem(
            title: item.title,
            detail: _previewDetail(operation, item),
            mediaId: item.id,
            path: _mediaPath(item),
          ),
        )
        .toList(growable: false);
    final plan = MediaAgentPlan(
      id: planId,
      operation: operation,
      title: operation.label,
      description: _description(operation, candidates.length, query, name),
      preview: preview,
      parameters: {
        'mediaIds': candidates.map((item) => item.id).toList(growable: false),
        if (operation == MediaAgentOperation.smartCollection) ...{
          'query': query.trim(),
          'name': name,
        },
      },
      createdAt: DateTime.now(),
    );
    await runs.create(plan);
    return plan;
  }

  Future<MediaAgentRun> confirm(String planId) async {
    final run = await runs.getById(planId);
    if (run == null) throw StateError('找不到 Agent 计划');
    if (run.status != MediaAgentRunStatus.planned) {
      throw StateError('这个计划当前不能确认：${run.status.name}');
    }
    await runs.setStatus(planId, MediaAgentRunStatus.confirmed);
    return (await runs.getById(planId))!;
  }

  Future<MediaAgentRun> execute(String planId) async {
    final run = await runs.getById(planId);
    if (run == null) throw StateError('找不到 Agent 计划');
    if (run.status != MediaAgentRunStatus.confirmed) {
      throw StateError('必须先确认计划才能执行');
    }
    await runs.setStatus(planId, MediaAgentRunStatus.running);
    try {
      final result = await _execute(run);
      await runs.setStatus(
        planId,
        MediaAgentRunStatus.succeeded,
        result: result,
      );
    } catch (error) {
      await runs.setStatus(
        planId,
        MediaAgentRunStatus.failed,
        error: error.toString(),
      );
    }
    return (await runs.getById(planId))!;
  }

  Future<MediaAgentRun> undo(String runId) async {
    final run = await runs.getById(runId);
    if (run == null) throw StateError('找不到 Agent 执行记录');
    if (run.status != MediaAgentRunStatus.succeeded) {
      throw StateError('只有成功执行的记录可以撤销');
    }
    switch (run.operation) {
      case MediaAgentOperation.batchSubtitles:
        final raw = run.result['artifacts'];
        if (raw is List) {
          for (final value in raw) {
            final path = value.toString();
            if (path.isEmpty) continue;
            final file = File(path);
            if (await file.exists()) await file.delete();
          }
        }
      case MediaAgentOperation.smartCollection:
        final collectionId = run.result['collectionId']?.toString();
        if (collectionId != null && collectionId.isNotEmpty) {
          await collections.deleteById(collectionId);
        }
      case MediaAgentOperation.findDuplicates ||
          MediaAgentOperation.inspectLowQuality ||
          MediaAgentOperation.listUnwatched ||
          MediaAgentOperation.customFilter ||
          MediaAgentOperation.libraryReport:
        break;
    }
    await runs.setStatus(runId, MediaAgentRunStatus.undone);
    return (await runs.getById(runId))!;
  }

  Future<List<MediaAgentRun>> history({int limit = 50}) =>
      runs.list(limit: limit);

  Future<void> recoverInterrupted() => runs.recoverInterrupted();

  Future<Map<String, dynamic>> _execute(MediaAgentRun run) async {
    final ids = _stringList(run.plan.parameters['mediaIds']);
    switch (run.operation) {
      case MediaAgentOperation.batchSubtitles:
        final generator = subtitleGenerator;
        if (generator == null) {
          throw StateError('本地 AI Worker 未配置，无法批量生成字幕');
        }
        final artifacts = <String>[];
        final errors = <String>[];
        var processed = 0;
        for (final id in ids) {
          final media = await mediaRepository.getById(id);
          if (media == null) {
            errors.add('$id: 媒体不存在');
            continue;
          }
          try {
            artifacts.addAll(await generator(media));
            processed++;
          } catch (error) {
            errors.add('${media.title}: $error');
          }
        }
        if (processed == 0 && ids.isNotEmpty) {
          throw StateError(errors.join('\n'));
        }
        return {
          'processed': processed,
          'failed': errors.length,
          'errors': errors,
          'artifacts': artifacts,
        };
      case MediaAgentOperation.findDuplicates:
      case MediaAgentOperation.inspectLowQuality:
      case MediaAgentOperation.listUnwatched:
      case MediaAgentOperation.customFilter:
      case MediaAgentOperation.libraryReport:
        return {'mediaIds': ids, 'count': ids.length};
      case MediaAgentOperation.smartCollection:
        final name = run.plan.parameters['name']?.toString() ?? '智能合集';
        final query = run.plan.parameters['query']?.toString() ?? '';
        final collection = await collections.upsert(
          name: name,
          query: query,
          mediaIds: ids,
        );
        return {'collectionId': collection.id, 'mediaIds': ids};
    }
  }

  Future<List<Media>> _unwatchedCandidates(List<Media> media) async {
    final result = <Media>[];
    final cutoff = DateTime.now().subtract(
      const Duration(days: longUnwatchedDays),
    );
    for (final item in media) {
      final progress = await progressRepository.getByMediaId(item.id);
      final addedAt = DateTime.tryParse(item.dateAdded);
      final oldEnough = addedAt == null || addedAt.isBefore(cutoff);
      final lastWatched = progress?.updatedAt;
      final watchedLongAgo =
          lastWatched == null || lastWatched.isBefore(cutoff);
      if (oldEnough &&
          (progress == null ||
              (progress.position <= Duration.zero && watchedLongAgo) ||
              (!progress.completed && watchedLongAgo))) {
        result.add(item);
      }
    }
    return result;
  }

  List<Media> _duplicateCandidates(List<Media> media) {
    final groups = <String, List<Media>>{};
    for (final item in media) {
      final hash = item.fileHash?.trim().toLowerCase();
      if (hash == null || hash.isEmpty) continue;
      groups.putIfAbsent(hash, () => []).add(item);
    }
    return groups.values
        .where((group) => group.length > 1)
        .expand((group) => group)
        .toList(growable: false);
  }

  Future<List<Media>> _collectionCandidates(
    List<Media> media,
    String query,
  ) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return media;

    final requiresUnwatched = RegExp(
      r'未观看|未看|没看|unwatched(?:\s*:\s*true)?',
    ).hasMatch(normalized);
    final normalizedTerms = normalized
        .replaceAll(
          RegExp(r'未观看|未看|没看|unwatched(?:\s*:\s*true)?'),
          ' ',
        )
        .replaceAll(RegExp(r'\b(?:and|or)\b|且|以及|并且|genre\s*:'), ' ')
        .split(RegExp(r'\s+'))
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList(growable: false);

    final matches = <Media>[];
    for (final item in media) {
      final haystack = [
        item.title,
        item.overview ?? '',
        item.genres.join(' '),
        item.path,
      ].join(' ').toLowerCase();
      if (!normalizedTerms.every(haystack.contains)) continue;

      if (requiresUnwatched) {
        final progress = await progressRepository.getByMediaId(item.id);
        if (progress != null && progress.position > Duration.zero) continue;
      }
      matches.add(item);
    }
    return matches;
  }

  bool _isSubtitleCandidate(Media item) {
    final path = _mediaPath(item);
    if (path == null) return false;
    final extension = p.extension(path).toLowerCase();
    return const {
      '.mp4',
      '.mkv',
      '.mov',
      '.m4v',
      '.avi',
      '.webm',
      '.ts',
      '.m2ts',
    }.contains(extension);
  }

  bool _isLowQuality(Media item) {
    final value = '${item.title} ${item.path} ${item.fullPath ?? ''}';
    return RegExp(
          r'(^|[ ._\-])(144|240|360|480|576|720)p($|[ ._\-])',
          caseSensitive: false,
        ).hasMatch(value) ||
        value.toLowerCase().contains('sd');
  }

  String? _mediaPath(Media item) {
    final raw = (item.fullPath?.trim().isNotEmpty == true)
        ? item.fullPath!.trim()
        : item.path.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri?.scheme == 'file') return uri!.toFilePath();
    if (uri?.hasScheme == true) return null;
    return raw;
  }

  String _previewDetail(MediaAgentOperation operation, Media item) =>
      switch (operation) {
        MediaAgentOperation.batchSubtitles => _mediaPath(item) ?? '仅支持本地文件',
        MediaAgentOperation.findDuplicates => '文件指纹：${item.fileHash ?? '未记录'}',
        MediaAgentOperation.inspectLowQuality => '文件名/路径包含低分辨率标记',
        MediaAgentOperation.smartCollection => [
          item.year,
          ...item.genres,
        ].where((value) => value.isNotEmpty).join(' · '),
        MediaAgentOperation.listUnwatched => '没有发现观看进度',
        MediaAgentOperation.customFilter => [
          item.year,
          if (item.rating != null) '⭐ ${item.rating}',
          ...item.genres,
        ].where((value) => value.isNotEmpty).join(' · '),
        MediaAgentOperation.libraryReport => '媒体类型: ${item.type.name} · 年份: ${item.year}',
      };

  String _description(
    MediaAgentOperation operation,
    int count,
    String query,
    String collectionName,
  ) {
    return switch (operation) {
      MediaAgentOperation.batchSubtitles => '将为 $count 个本地视频生成字幕缓存，不改写原视频文件。',
      MediaAgentOperation.findDuplicates => '发现 $count 个可能重复的媒体条目，只生成报告，不删除文件。',
      MediaAgentOperation.inspectLowQuality =>
        '发现 $count 个疑似低画质媒体，只生成报告，不移动文件。',
      MediaAgentOperation.smartCollection =>
        '将创建“$collectionName”，包含 $count 个媒体条目，规则：${query.trim().isEmpty ? '当前筛选结果' : query.trim()}。',
      MediaAgentOperation.listUnwatched => '发现 $count 个没有观看记录的媒体，只生成清单。',
      MediaAgentOperation.customFilter => '符合筛选条件的媒体共有 $count 项，查询规则：${query.trim().isEmpty ? '默认全库' : query.trim()}。',
      MediaAgentOperation.libraryReport => '媒体库全盘扫描完成，共统计 $count 项媒体数据。',
    };
  }

  List<String> _stringList(Object? value) => value is List
      ? value
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : const [];
}
