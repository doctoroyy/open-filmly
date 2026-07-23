import 'dart:io';

import 'package:path/path.dart' as p;

import 'ai_provider.dart';
import 'transcript_service.dart';

/// Parses local sidecar subtitle files into the intelligence transcript store
/// so Ask Filmly and Companion work without waiting for ASR.
class SubtitleIngestService {
  const SubtitleIngestService(this._transcripts);

  final TranscriptService _transcripts;

  Future<List<ProviderTranscriptSegment>> parseFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    final extension = p.extension(path).toLowerCase();
    if (extension == '.vtt') return parseVtt(raw);
    return parseSrt(raw);
  }

  /// Ingests a sidecar file into [assetId], replacing previous transcript rows
  /// for that asset. Returns the number of segments written.
  Future<int> ingestFile({
    required String assetId,
    required String path,
    String language = '',
  }) async {
    final segments = await parseFile(path);
    if (segments.isEmpty) return 0;
    final detected = language.trim().isNotEmpty
        ? language.trim()
        : _languageHintFromPath(path);
    await _transcripts.saveProviderResult(
      assetId,
      TranscriptionResult(
        language: detected,
        segments: [
          for (final segment in segments)
            ProviderTranscriptSegment(
              startMs: segment.startMs,
              endMs: segment.endMs,
              text: segment.text,
              language: segment.language.isEmpty ? detected : segment.language,
              confidence: segment.confidence,
              speaker: segment.speaker,
            ),
        ],
      ),
    );
    return segments.length;
  }

  List<ProviderTranscriptSegment> parseSrt(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) return const [];
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final segments = <ProviderTranscriptSegment>[];
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      if (lines.length < 2) continue;
      final timingLine = lines.firstWhere(
        (line) => line.contains('-->'),
        orElse: () => '',
      );
      if (timingLine.isEmpty) continue;
      final timing = _parseTiming(timingLine);
      if (timing == null) continue;
      final textLines = lines
          .skipWhile((line) => !line.contains('-->'))
          .skip(1)
          .map(_stripTags)
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      final text = textLines.join(' ').trim();
      if (text.isEmpty || timing.endMs <= timing.startMs) continue;
      segments.add(
        ProviderTranscriptSegment(
          startMs: timing.startMs,
          endMs: timing.endMs,
          text: text,
        ),
      );
    }
    return segments;
  }

  List<ProviderTranscriptSegment> parseVtt(String raw) {
    final withoutHeader = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceFirst(RegExp(r'^WEBVTT[^\n]*\n+'), '');
    return parseSrt(withoutHeader);
  }

  ({int startMs, int endMs})? _parseTiming(String line) {
    final match = RegExp(
      r'(\d{1,2}:)?\d{1,2}:\d{2}[.,]\d{1,3}\s*-->\s*(\d{1,2}:)?\d{1,2}:\d{2}[.,]\d{1,3}',
    ).firstMatch(line);
    if (match == null) return null;
    final parts = line.split('-->');
    if (parts.length < 2) return null;
    final start = _parseTimestamp(parts[0].trim());
    final end = _parseTimestamp(parts[1].trim().split(RegExp(r'\s+')).first);
    if (start == null || end == null) return null;
    return (startMs: start, endMs: end);
  }

  int? _parseTimestamp(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    final pieces = cleaned.split(':');
    if (pieces.length < 2 || pieces.length > 3) return null;
    try {
      if (pieces.length == 2) {
        final minutes = int.parse(pieces[0]);
        final secondsParts = pieces[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final millis = _parseMillis(secondsParts.length > 1 ? secondsParts[1] : '0');
        return ((minutes * 60) + seconds) * 1000 + millis;
      }
      final hours = int.parse(pieces[0]);
      final minutes = int.parse(pieces[1]);
      final secondsParts = pieces[2].split('.');
      final seconds = int.parse(secondsParts[0]);
      final millis = _parseMillis(secondsParts.length > 1 ? secondsParts[1] : '0');
      return (((hours * 60) + minutes) * 60 + seconds) * 1000 + millis;
    } catch (_) {
      return null;
    }
  }

  int _parseMillis(String value) {
    final digits = value.padRight(3, '0').substring(0, 3);
    return int.parse(digits);
  }

  String _stripTags(String value) =>
      value.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\{[^}]+\}'), '').trim();

  String _languageHintFromPath(String path) {
    final name = p.basename(path).toLowerCase();
    if (RegExp(r'(chs|zh-cn|zh|chi|cn|sc)').hasMatch(name)) return 'zh-CN';
    if (RegExp(r'(cht|zh-tw|zh-hk|tc)').hasMatch(name)) return 'zh-TW';
    if (RegExp(r'(en|eng)').hasMatch(name)) return 'en';
    if (RegExp(r'(ja|jp|jpn)').hasMatch(name)) return 'ja';
    return '';
  }
}
