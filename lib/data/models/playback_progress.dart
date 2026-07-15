import 'dart:math' as math;

/// Persisted playback progress for a single library item.
class PlaybackProgress {
  const PlaybackProgress({
    required this.mediaId,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.completed = false,
  });

  static const minimumPersistPosition = Duration(seconds: 5);
  static const minimumResumePosition = Duration(seconds: 30);

  final String mediaId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;
  final bool completed;

  static PlaybackProgress? capture({
    required String mediaId,
    required Duration position,
    required Duration duration,
    bool completed = false,
    DateTime? now,
  }) {
    final safePosition = position < Duration.zero ? Duration.zero : position;
    final safeDuration = duration < Duration.zero ? Duration.zero : duration;
    final finished = completed || _isNearEnd(safePosition, safeDuration);

    if (!finished && safePosition < minimumPersistPosition) {
      return null;
    }

    return PlaybackProgress(
      mediaId: mediaId,
      position: finished && safeDuration > Duration.zero
          ? safeDuration
          : safePosition,
      duration: safeDuration,
      updatedAt: now ?? DateTime.now(),
      completed: finished,
    );
  }

  factory PlaybackProgress.fromJson(String mediaId, Map<String, dynamic> json) {
    return PlaybackProgress(
      mediaId: mediaId,
      position: Duration(
        milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0,
      ),
      duration: Duration(
        milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completed: json['completed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'updatedAt': updatedAt.toIso8601String(),
    'completed': completed,
  };

  bool get hasResumePoint => !completed && position >= minimumResumePosition;

  bool get shouldSurface => hasResumePoint;

  double get fractionWatched {
    if (duration <= Duration.zero) return 0;
    final fraction = position.inMilliseconds / duration.inMilliseconds;
    return math.max(0, math.min(1, fraction));
  }

  String get progressLabel => duration > Duration.zero
      ? '${formatClock(position)} / ${formatClock(duration)}'
      : formatClock(position);

  static String formatClock(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  static bool _isNearEnd(Duration position, Duration duration) {
    if (duration <= Duration.zero) return false;
    return position.inMilliseconds >= (duration.inMilliseconds * 0.95).round();
  }
}
