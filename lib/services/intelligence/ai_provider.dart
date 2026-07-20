import 'ai_worker_client.dart';
import 'ai_worker_manager.dart';

class ProviderTranscriptSegment {
  const ProviderTranscriptSegment({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.language = '',
    this.confidence,
    this.speaker,
  });

  final int startMs;
  final int endMs;
  final String text;
  final String language;
  final double? confidence;
  final String? speaker;
}

class TranscriptionResult {
  const TranscriptionResult({required this.language, required this.segments});

  final String language;
  final List<ProviderTranscriptSegment> segments;
}

class TranslationResult {
  const TranslationResult({required this.language, required this.texts});

  final String language;
  final List<String> texts;
}

class AiProviderUnavailable implements Exception {
  const AiProviderUnavailable(this.message);

  final String message;

  @override
  String toString() => 'AiProviderUnavailable: $message';
}

abstract class AiProvider {
  String get id;

  Future<Map<String, dynamic>> probe(
    String path, {
    void Function(double progress)? onProgress,
  });

  Future<TranscriptionResult> transcribe({
    required String path,
    required String language,
    required String model,
    void Function(double progress)? onProgress,
  });

  Future<TranslationResult> translate({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
    required String model,
    void Function(double progress)? onProgress,
  }) => Future.error(
    const AiProviderUnavailable('Translation adapter is not configured'),
  );

  Future<List<double>> embed({required String text, required String model}) =>
      Future.error(
        const AiProviderUnavailable('Embedding adapter is not configured'),
      );

  Future<List<String>> sampleFrames({
    required String path,
    required String outputDirectory,
    required int durationMs,
    int count = 12,
    void Function(double progress)? onProgress,
  }) => Future.error(
    const AiProviderUnavailable('Frame sampling adapter is not configured'),
  );
}

class LocalWorkerProvider implements AiProvider {
  LocalWorkerProvider(this._client, {this.modelDirectory = ''});

  final AiWorkerClient _client;
  final String modelDirectory;

  @override
  String get id => 'local-worker';

  @override
  Future<Map<String, dynamic>> probe(
    String path, {
    void Function(double progress)? onProgress,
  }) {
    return _client.request('probe', {'path': path}, onProgress: onProgress);
  }

  @override
  Future<TranscriptionResult> transcribe({
    required String path,
    required String language,
    required String model,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _client.request('transcribe', {
      'path': path,
      'language': language,
      'model': model,
      'modelDirectory': modelDirectory,
    }, onProgress: onProgress);
    final rawSegments = result['segments'];
    final segments = rawSegments is List
        ? rawSegments
              .whereType<Map>()
              .map((raw) {
                final map = Map<String, dynamic>.from(raw);
                return ProviderTranscriptSegment(
                  startMs: (map['startMs'] as num?)?.round() ?? 0,
                  endMs: (map['endMs'] as num?)?.round() ?? 0,
                  text: map['text']?.toString() ?? '',
                  language: map['language']?.toString() ?? language,
                  confidence: (map['confidence'] as num?)?.toDouble(),
                  speaker: map['speaker']?.toString(),
                );
              })
              .toList(growable: false)
        : const <ProviderTranscriptSegment>[];
    return TranscriptionResult(
      language: result['language']?.toString() ?? language,
      segments: segments,
    );
  }

  @override
  Future<TranslationResult> translate({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
    required String model,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _client.request('translate', {
      'texts': texts,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'model': model,
    }, onProgress: onProgress);
    final rawTexts = result['texts'];
    return TranslationResult(
      language: result['language']?.toString() ?? targetLanguage,
      texts: rawTexts is List
          ? rawTexts.map((value) => value.toString()).toList(growable: false)
          : const [],
    );
  }

  @override
  Future<List<double>> embed({
    required String text,
    required String model,
  }) async {
    final result = await _client.request('embed', {
      'text': text,
      'model': model,
    });
    final vector = result['vector'];
    return vector is List
        ? vector
              .whereType<num>()
              .map((value) => value.toDouble())
              .toList(growable: false)
        : const [];
  }

  @override
  Future<List<String>> sampleFrames({
    required String path,
    required String outputDirectory,
    required int durationMs,
    int count = 12,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _client.request('sample_frames', {
      'path': path,
      'outputDirectory': outputDirectory,
      'durationMs': durationMs,
      'count': count,
    }, onProgress: onProgress);
    final paths = result['paths'];
    return paths is List
        ? paths.map((value) => value.toString()).toList(growable: false)
        : const [];
  }
}

/// Provider variant used by the application runtime. It obtains the shared
/// worker client lazily and retries once after a worker-side transport error.
class ManagedLocalWorkerProvider implements AiProvider {
  ManagedLocalWorkerProvider(this._manager, {this.modelDirectory = ''});

  final AiWorkerManager _manager;
  final String modelDirectory;

  @override
  String get id => 'local-worker';

  @override
  Future<Map<String, dynamic>> probe(
    String path, {
    void Function(double progress)? onProgress,
  }) => _manager.request('probe', {'path': path}, onProgress: onProgress);

  @override
  Future<TranscriptionResult> transcribe({
    required String path,
    required String language,
    required String model,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _manager.request('transcribe', {
      'path': path,
      'language': language,
      'model': model,
      'modelDirectory': modelDirectory,
    }, onProgress: onProgress);
    return TranscriptionResult(
      language: result['language']?.toString() ?? language,
      segments: _segments(result['segments'], language),
    );
  }

  @override
  Future<TranslationResult> translate({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
    required String model,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _manager.request('translate', {
      'texts': texts,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'model': model,
    }, onProgress: onProgress);
    final rawTexts = result['texts'];
    return TranslationResult(
      language: result['language']?.toString() ?? targetLanguage,
      texts: rawTexts is List
          ? rawTexts.map((value) => value.toString()).toList(growable: false)
          : const [],
    );
  }

  @override
  Future<List<double>> embed({
    required String text,
    required String model,
  }) async {
    final result = await _manager.request('embed', {
      'text': text,
      'model': model,
    });
    final vector = result['vector'];
    return vector is List
        ? vector
              .whereType<num>()
              .map((value) => value.toDouble())
              .toList(growable: false)
        : const [];
  }

  @override
  Future<List<String>> sampleFrames({
    required String path,
    required String outputDirectory,
    required int durationMs,
    int count = 12,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _manager.request('sample_frames', {
      'path': path,
      'outputDirectory': outputDirectory,
      'durationMs': durationMs,
      'count': count,
    }, onProgress: onProgress);
    final paths = result['paths'];
    return paths is List
        ? paths.map((value) => value.toString()).toList(growable: false)
        : const [];
  }

  List<ProviderTranscriptSegment> _segments(Object? raw, String language) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((value) {
          final map = Map<String, dynamic>.from(value);
          return ProviderTranscriptSegment(
            startMs: (map['startMs'] as num?)?.round() ?? 0,
            endMs: (map['endMs'] as num?)?.round() ?? 0,
            text: map['text']?.toString() ?? '',
            language: map['language']?.toString() ?? language,
            confidence: (map['confidence'] as num?)?.toDouble(),
            speaker: map['speaker']?.toString(),
          );
        })
        .toList(growable: false);
  }
}
