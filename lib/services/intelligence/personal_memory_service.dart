import 'dart:convert';

import '../../data/intelligence/intelligence_asset_repository.dart';
import '../../data/intelligence/watch_event_repository.dart';
import '../../data/models/media.dart';
import '../../data/repositories/media_repository.dart';

class MemoryRecentItem {
  const MemoryRecentItem({
    required this.title,
    required this.kind,
    required this.positionMs,
    required this.occurredAt,
    this.assetId,
  });

  final String title;
  final WatchEventKind kind;
  final int positionMs;
  final DateTime occurredAt;
  final String? assetId;
}

class PersonalMemorySummary {
  const PersonalMemorySummary({
    required this.totalEvents,
    required this.watchedAssets,
    required this.completedAssets,
    required this.repeatAssets,
    required this.topicCounts,
    required this.recent,
  });

  final int totalEvents;
  final int watchedAssets;
  final int completedAssets;
  final int repeatAssets;
  final Map<String, int> topicCounts;
  final List<MemoryRecentItem> recent;
}

/// Local-only viewing memory. It intentionally stores references to stable AI
/// asset identities rather than copying media metadata into a second library.
class PersonalMemoryService {
  PersonalMemoryService({
    required this.events,
    required this.assets,
    required this.mediaRepository,
  });

  final WatchEventRepository events;
  final IntelligenceAssetRepository assets;
  final MediaRepository mediaRepository;

  Future<WatchEvent?> record({
    required String assetId,
    required WatchEventKind kind,
    required int positionMs,
    int? durationMs,
    Map<String, dynamic> payload = const {},
  }) {
    return _record(
      assetId: assetId,
      kind: kind,
      positionMs: positionMs,
      durationMs: durationMs,
      payload: payload,
    );
  }

  Future<WatchEvent> _record({
    required String assetId,
    required WatchEventKind kind,
    required int positionMs,
    int? durationMs,
    required Map<String, dynamic> payload,
  }) async {
    if (kind == WatchEventKind.play) {
      final previous = await events.list(assetId: assetId, limit: 100);
      if (previous.any(
        (event) =>
            event.kind == WatchEventKind.play ||
            event.kind == WatchEventKind.completed,
      )) {
        await events.record(
          assetId: assetId,
          kind: WatchEventKind.repeat,
          positionMs: positionMs,
          durationMs: durationMs,
          payload: payload,
        );
      }
    }
    return events.record(
      assetId: assetId,
      kind: kind,
      positionMs: positionMs,
      durationMs: durationMs,
      payload: payload,
    );
  }

  Future<PersonalMemorySummary> summary() async {
    final rows = await events.list(limit: 10000);
    final mediaByAsset = <String, Media?>{};
    for (final assetId in rows.map((row) => row.assetId).toSet()) {
      final asset = await assets.getById(assetId);
      mediaByAsset[assetId] = asset?.mediaId == null
          ? await mediaRepository.getById(assetId)
          : await mediaRepository.getById(asset!.mediaId!);
    }

    final watched = rows
        .where(
          (event) =>
              event.kind == WatchEventKind.play ||
              event.kind == WatchEventKind.progress ||
              event.kind == WatchEventKind.completed,
        )
        .map((event) => event.assetId)
        .toSet();
    final completed = rows
        .where((event) => event.kind == WatchEventKind.completed)
        .map((event) => event.assetId)
        .toSet();
    final playCounts = <String, int>{};
    for (final event in rows.where(
      (event) => event.kind == WatchEventKind.play,
    )) {
      playCounts.update(event.assetId, (count) => count + 1, ifAbsent: () => 1);
    }
    final repeatAssets = playCounts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();
    final topicCounts = <String, int>{};
    for (final assetId in watched) {
      final media = mediaByAsset[assetId];
      for (final genre in media?.genres ?? const <String>[]) {
        final topic = genre.trim();
        if (topic.isNotEmpty) {
          topicCounts.update(topic, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }
    final sortedTopics = topicCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final recent = rows
        .take(20)
        .map((event) {
          final media = mediaByAsset[event.assetId];
          return MemoryRecentItem(
            title: media?.title ?? '未匹配媒体',
            kind: event.kind,
            positionMs: event.positionMs,
            occurredAt: event.occurredAt,
            assetId: event.assetId,
          );
        })
        .toList(growable: false);
    return PersonalMemorySummary(
      totalEvents: rows.length,
      watchedAssets: watched.length,
      completedAssets: completed.length,
      repeatAssets: repeatAssets.length,
      topicCounts: {for (final entry in sortedTopics) entry.key: entry.value},
      recent: recent,
    );
  }

  Future<void> clear() => events.clear();

  Future<String> exportJson() => events.exportJson();

  /// A compact local prompt/context representation for future AI providers.
  /// It contains no future-facing content and is never uploaded by this class.
  Future<String> localContext({int limit = 30}) async {
    final rows = await events.list(limit: limit);
    return jsonEncode({'events': rows.map((event) => event.toJson()).toList()});
  }
}
