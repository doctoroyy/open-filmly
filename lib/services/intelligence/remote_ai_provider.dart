import 'ai_provider.dart';

/// Remote providers are intentionally behind the same interface as the local
/// worker. A concrete HTTP adapter can be added without changing task or UI
/// code; the first release never uploads media implicitly.
class RemoteAiProvider implements AiProvider {
  const RemoteAiProvider({required this.providerName});

  final String providerName;

  @override
  String get id => 'remote:$providerName';

  @override
  Future<Map<String, dynamic>> probe(
    String path, {
    void Function(double progress)? onProgress,
  }) => Future.error(
    const AiProviderUnavailable('Remote probe adapter is not configured'),
  );

  @override
  Future<TranscriptionResult> transcribe({
    required String path,
    required String language,
    required String model,
    void Function(double progress)? onProgress,
  }) => Future.error(
    const AiProviderUnavailable(
      'Remote transcription adapter is not configured',
    ),
  );

  @override
  Future<TranslationResult> translate({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
    required String model,
    void Function(double progress)? onProgress,
  }) => Future.error(
    const AiProviderUnavailable('Remote translation adapter is not configured'),
  );

  @override
  Future<List<double>> embed({required String text, required String model}) =>
      Future.error(
        const AiProviderUnavailable(
          'Remote embedding adapter is not configured',
        ),
      );

  @override
  Future<List<String>> sampleFrames({
    required String path,
    required String outputDirectory,
    required int durationMs,
    int count = 12,
    void Function(double progress)? onProgress,
  }) => Future.error(
    const AiProviderUnavailable('Remote frame sampling is not supported'),
  );
}
