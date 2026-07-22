import 'dart:convert';

enum MediaAgentOperation {
  batchSubtitles,
  findDuplicates,
  inspectLowQuality,
  smartCollection,
  listUnwatched,
  customFilter,
  libraryReport;

  static MediaAgentOperation fromName(String value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => values.first,
  );

  String get label => switch (this) {
    MediaAgentOperation.batchSubtitles => '批量生成字幕',
    MediaAgentOperation.findDuplicates => '查找重复媒体',
    MediaAgentOperation.inspectLowQuality => '检查低画质文件',
    MediaAgentOperation.smartCollection => '建立智能合集',
    MediaAgentOperation.listUnwatched => '列出长期未观看内容',
    MediaAgentOperation.customFilter => '条件组合筛选报告',
    MediaAgentOperation.libraryReport => '影视库全盘统计与健康度分析',
  };
}

enum MediaAgentRunStatus {
  planned,
  confirmed,
  running,
  succeeded,
  failed,
  undone;

  static MediaAgentRunStatus fromName(String value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => MediaAgentRunStatus.planned,
  );
}

class AgentPreviewItem {
  const AgentPreviewItem({
    required this.title,
    required this.detail,
    this.mediaId,
    this.path,
  });

  final String title;
  final String detail;
  final String? mediaId;
  final String? path;

  Map<String, dynamic> toJson() => {
    'title': title,
    'detail': detail,
    if (mediaId != null) 'mediaId': mediaId,
    if (path != null) 'path': path,
  };

  factory AgentPreviewItem.fromJson(Map<String, dynamic> json) =>
      AgentPreviewItem(
        title: json['title']?.toString() ?? '',
        detail: json['detail']?.toString() ?? '',
        mediaId: json['mediaId']?.toString(),
        path: json['path']?.toString(),
      );
}

class MediaAgentPlan {
  const MediaAgentPlan({
    required this.id,
    required this.operation,
    required this.title,
    required this.description,
    required this.preview,
    this.parameters = const {},
    required this.createdAt,
  });

  final String id;
  final MediaAgentOperation operation;
  final String title;
  final String description;
  final List<AgentPreviewItem> preview;
  final Map<String, dynamic> parameters;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation.name,
    'title': title,
    'description': description,
    'preview': preview.map((item) => item.toJson()).toList(),
    'parameters': parameters,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MediaAgentPlan.fromJson(Map<String, dynamic> json) {
    final rawPreview = json['preview'];
    final rawParameters = json['parameters'];
    return MediaAgentPlan(
      id: json['id']?.toString() ?? '',
      operation: MediaAgentOperation.fromName(
        json['operation']?.toString() ?? '',
      ),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      preview: rawPreview is List
          ? rawPreview
                .whereType<Map>()
                .map(
                  (item) => AgentPreviewItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      parameters: rawParameters is Map
          ? Map<String, dynamic>.from(rawParameters)
          : const {},
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class MediaAgentRun {
  const MediaAgentRun({
    required this.id,
    this.conversationId,
    required this.operation,
    required this.status,
    required this.plan,
    required this.preview,
    this.result = const {},
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? conversationId;
  final MediaAgentOperation operation;
  final MediaAgentRunStatus status;
  final MediaAgentPlan plan;
  final List<AgentPreviewItem> preview;
  final Map<String, dynamic> result;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SmartCollection {
  const SmartCollection({
    required this.id,
    required this.name,
    required this.query,
    required this.mediaIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String query;
  final List<String> mediaIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'query': query,
    'mediaIds': mediaIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

String encodeJson(Object value) => jsonEncode(value);

class MediaAgentChatMessage {
  const MediaAgentChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
    this.plan,
    required this.timestamp,
  });

  final String id;
  final bool isUser;
  final String content;
  final MediaAgentPlan? plan;
  final DateTime timestamp;
}

/// A durable local conversation. Conversations are intentionally stored in the
/// intelligence database so they can be removed independently of the core
/// media library and playback data.
class AgentConversation {
  const AgentConversation({
    required this.id,
    required this.title,
    required this.preview,
    this.pinnedAt,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String preview;
  final DateTime? pinnedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPinned => pinnedAt != null;
  bool get isArchived => archivedAt != null;
}

enum AgentConversationRole {
  user,
  model,
  system;

  static AgentConversationRole fromName(String value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => AgentConversationRole.system,
  );
}

enum AgentConversationMessageStatus {
  complete,
  failed,
  cancelled;

  static AgentConversationMessageStatus fromName(String value) =>
      values.firstWhere(
        (item) => item.name == value,
        orElse: () => AgentConversationMessageStatus.complete,
      );
}

class AgentConversationMessage {
  const AgentConversationMessage({
    required this.id,
    required this.conversationId,
    required this.sequence,
    required this.role,
    required this.content,
    this.toolsUsed = const [],
    this.planId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final int sequence;
  final AgentConversationRole role;
  final String content;
  final List<String> toolsUsed;
  final String? planId;
  final AgentConversationMessageStatus status;
  final DateTime createdAt;
}

/// The only persisted information sent back to a provider for a prior turn.
/// Tool payloads and internal provider messages deliberately do not become
/// part of this model context.
class AgentModelContextMessage {
  const AgentModelContextMessage({required this.role, required this.content});

  final AgentConversationRole role;
  final String content;
}
