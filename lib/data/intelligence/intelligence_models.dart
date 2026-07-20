enum AiJobStatus {
  queued,
  running,
  succeeded,
  failed,
  cancelled;

  static AiJobStatus fromName(String value) => AiJobStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => AiJobStatus.queued,
  );
}

enum AiTaskType {
  probe,
  transcribe,
  translate,
  embed,
  sampleFrames,
  sceneIndex;

  static AiTaskType fromName(String value) => AiTaskType.values.firstWhere(
    (task) => task.name == value,
    orElse: () => AiTaskType.probe,
  );
}

class AiJob {
  const AiJob({
    required this.id,
    required this.assetId,
    required this.taskType,
    required this.model,
    required this.status,
    required this.progress,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.checkpoint,
    this.error,
  });

  final String id;
  final String assetId;
  final AiTaskType taskType;
  final String model;
  final AiJobStatus status;
  final double progress;
  final int attempts;
  final String? checkpoint;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TranscriptSegment {
  const TranscriptSegment({
    required this.id,
    required this.assetId,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.language,
    this.translatedText,
    this.confidence,
    this.speaker,
    this.createdAt,
  });

  final String id;
  final String assetId;
  final int startMs;
  final int endMs;
  final String text;
  final String language;
  final String? translatedText;
  final double? confidence;
  final String? speaker;
  final DateTime? createdAt;
}

class ContentSegment {
  const ContentSegment({
    required this.id,
    required this.assetId,
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.summary,
    required this.searchText,
    this.peopleJson,
    this.placesJson,
    this.themesJson,
    this.screenshotPath,
    this.createdAt,
  });

  final String id;
  final String assetId;
  final int startMs;
  final int endMs;
  final String title;
  final String summary;
  final String searchText;
  final String? peopleJson;
  final String? placesJson;
  final String? themesJson;
  final String? screenshotPath;
  final DateTime? createdAt;
}
