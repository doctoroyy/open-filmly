import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../data/intelligence/intelligence_database.dart';

class IntelligenceBundleException implements Exception {
  const IntelligenceBundleException(this.message);

  final String message;

  @override
  String toString() => 'IntelligenceBundleException: $message';
}

/// Exports and imports AI data without copying or migrating the core media
/// database. The directory format is deliberately transparent so it can be
/// zipped by the caller or transferred through any existing sync feature.
class IntelligenceBundleService {
  IntelligenceBundleService(this._database);

  static const formatVersion = 1;
  final IntelligenceDatabase _database;

  Future<Directory> exportToDirectory(Directory directory) async {
    await directory.create(recursive: true);
    final assets = await _database.select(_database.intelligenceAssets).get();
    final transcripts = await _database
        .select(_database.transcriptSegments)
        .get();
    final events = await _database.select(_database.watchEvents).get();

    await _writeJson(File('${directory.path}/manifest.json'), {
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'counts': {
        'assets': assets.length,
        'transcripts': transcripts.length,
        'watchEvents': events.length,
      },
    });
    await _writeJson(
      File('${directory.path}/assets.json'),
      assets
          .map(
            (row) => {
              'id': row.id,
              'mediaId': row.mediaId,
              'episodeId': row.episodeId,
              'sourceScope': row.sourceScope,
              'canonicalUri': row.canonicalUri,
              'identityKey': row.identityKey,
              'fileHash': row.fileHash,
              'fileSize': row.fileSize,
              'modifiedAt': row.modifiedAt,
              'durationMs': row.durationMs,
              'status': row.status,
              'createdAt': row.createdAt,
              'updatedAt': row.updatedAt,
            },
          )
          .toList(growable: false),
    );
    await _writeJson(
      File('${directory.path}/transcripts.json'),
      transcripts
          .map(
            (row) => {
              'id': row.id,
              'assetId': row.assetId,
              'startMs': row.startMs,
              'endMs': row.endMs,
              'content': row.content,
              'language': row.language,
              'translatedText': row.translatedText,
              'confidence': row.confidence,
              'speaker': row.speaker,
              'createdAt': row.createdAt,
            },
          )
          .toList(growable: false),
    );
    await _writeJson(
      File('${directory.path}/watch_events.json'),
      events
          .map(
            (row) => {
              'id': row.id,
              'assetId': row.assetId,
              'kind': row.kind,
              'positionMs': row.positionMs,
              'durationMs': row.durationMs,
              'occurredAt': row.occurredAt,
              'payload': row.payload,
            },
          )
          .toList(growable: false),
    );
    return directory;
  }

  Future<void> importFromDirectory(Directory directory) async {
    final manifest = await _readMap(File('${directory.path}/manifest.json'));
    if (manifest['formatVersion'] != formatVersion) {
      throw const IntelligenceBundleException('不支持的 Intelligence bundle 版本');
    }
    final assets = await _readList(File('${directory.path}/assets.json'));
    final transcripts = await _readList(
      File('${directory.path}/transcripts.json'),
    );
    final events = await _readList(File('${directory.path}/watch_events.json'));

    await _database.transaction(() async {
      for (final raw in assets) {
        await _database
            .into(_database.intelligenceAssets)
            .insertOnConflictUpdate(
              IntelligenceAssetsCompanion.insert(
                id: raw['id'].toString(),
                mediaId: Value(raw['mediaId']?.toString()),
                episodeId: Value(raw['episodeId']?.toString()),
                sourceScope: raw['sourceScope'].toString(),
                canonicalUri: raw['canonicalUri'].toString(),
                identityKey: raw['identityKey'].toString(),
                fileHash: Value(raw['fileHash']?.toString()),
                fileSize: Value((raw['fileSize'] as num?)?.toInt()),
                modifiedAt: Value((raw['modifiedAt'] as num?)?.toInt()),
                durationMs: Value((raw['durationMs'] as num?)?.toInt()),
                status: Value(raw['status']?.toString() ?? 'pending'),
                createdAt:
                    raw['createdAt']?.toString() ??
                    DateTime.now().toIso8601String(),
                updatedAt:
                    raw['updatedAt']?.toString() ??
                    DateTime.now().toIso8601String(),
              ),
            );
      }
      for (final raw in transcripts) {
        await _database
            .into(_database.transcriptSegments)
            .insertOnConflictUpdate(
              TranscriptSegmentsCompanion.insert(
                id: raw['id'].toString(),
                assetId: raw['assetId'].toString(),
                startMs: (raw['startMs'] as num?)?.toInt() ?? 0,
                endMs: (raw['endMs'] as num?)?.toInt() ?? 0,
                content: raw['content']?.toString() ?? '',
                language: Value(raw['language']?.toString() ?? ''),
                translatedText: Value(raw['translatedText']?.toString()),
                confidence: Value((raw['confidence'] as num?)?.toDouble()),
                speaker: Value(raw['speaker']?.toString()),
                createdAt:
                    raw['createdAt']?.toString() ??
                    DateTime.now().toIso8601String(),
              ),
            );
      }
      for (final raw in events) {
        await _database
            .into(_database.watchEvents)
            .insert(
              WatchEventsCompanion.insert(
                id: raw['id'].toString(),
                assetId: raw['assetId'].toString(),
                kind: raw['kind'].toString(),
                positionMs: (raw['positionMs'] as num?)?.toInt() ?? 0,
                durationMs: Value((raw['durationMs'] as num?)?.toInt()),
                occurredAt: raw['occurredAt'].toString(),
                payload: Value(raw['payload']?.toString()),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  Future<void> _writeJson(File file, Object value) async {
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(value));
  }

  Future<Map<String, dynamic>> _readMap(File file) async {
    if (!await file.exists()) {
      throw IntelligenceBundleException('缺少 ${file.path}');
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map) throw IntelligenceBundleException('格式错误：${file.path}');
    return Map<String, dynamic>.from(value);
  }

  Future<List<Map<String, dynamic>>> _readList(File file) async {
    if (!await file.exists()) return const [];
    final value = jsonDecode(await file.readAsString());
    if (value is! List) throw IntelligenceBundleException('格式错误：${file.path}');
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }
}
