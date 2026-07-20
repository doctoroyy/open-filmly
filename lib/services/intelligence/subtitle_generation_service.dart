import 'dart:io';

import '../../data/intelligence/intelligence_models.dart';
import 'intelligence_storage.dart';
import 'transcript_service.dart';

class SubtitleArtifact {
  const SubtitleArtifact({
    required this.file,
    required this.language,
    required this.segmentCount,
  });

  final File file;
  final String language;
  final int segmentCount;
}

class SubtitleGenerationService {
  SubtitleGenerationService(this._transcripts);

  final TranscriptService _transcripts;

  Future<SubtitleArtifact> writeSrt({
    required String assetId,
    required Directory directory,
    required String language,
    bool translated = false,
  }) async {
    final segments = await _transcripts.getByAsset(assetId);
    final file = File('${directory.path}/$assetId.$language.srt');
    await directory.create(recursive: true);
    await file.writeAsString(
      _transcripts.toSrt(segments, translated: translated),
    );
    return SubtitleArtifact(
      file: file,
      language: language,
      segmentCount: segments.length,
    );
  }

  Future<SubtitleArtifact> writeVtt({
    required String assetId,
    required Directory directory,
    required String language,
    bool translated = false,
  }) async {
    final segments = await _transcripts.getByAsset(assetId);
    final file = File('${directory.path}/$assetId.$language.vtt');
    await directory.create(recursive: true);
    await file.writeAsString(
      _transcripts.toVtt(segments, translated: translated),
    );
    return SubtitleArtifact(
      file: file,
      language: language,
      segmentCount: segments.length,
    );
  }

  Future<List<SubtitleArtifact>> writeArtifacts({
    required String assetId,
    required String language,
    Directory? directory,
    bool translated = false,
  }) async {
    final outputDirectory = directory ?? await _defaultDirectory();
    return [
      await writeSrt(
        assetId: assetId,
        directory: outputDirectory,
        language: language,
        translated: translated,
      ),
      await writeVtt(
        assetId: assetId,
        directory: outputDirectory,
        language: language,
        translated: translated,
      ),
    ];
  }

  String render(
    Iterable<TranscriptSegment> segments, {
    bool translated = false,
  }) => _transcripts.toSrt(segments, translated: translated);

  String renderVtt(
    Iterable<TranscriptSegment> segments, {
    bool translated = false,
  }) => _transcripts.toVtt(segments, translated: translated);

  Future<Directory> _defaultDirectory() async {
    final root = await defaultIntelligenceDirectory();
    return Directory('${root.path}/subtitles');
  }
}
