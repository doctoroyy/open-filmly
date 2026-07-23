import 'dart:io';

import '../../data/intelligence/intelligence_asset_repository.dart';
import '../../data/models/media.dart';
import '../../data/repositories/media_repository.dart';
import '../playback/external_subtitle_finder.dart';
import 'content_segment_service.dart';
import 'local_embedding_service.dart';
import 'media_identity_service.dart';
import 'subtitle_ingest_service.dart';
import 'transcript_service.dart';

class LibraryIndexProgress {
  const LibraryIndexProgress({
    required this.scanned,
    required this.indexed,
    required this.withTranscripts,
    required this.skipped,
    required this.errors,
  });

  final int scanned;
  final int indexed;
  final int withTranscripts;
  final int skipped;
  final List<String> errors;
}

/// Turns an ordinary media library into a searchable personal media graph by
/// registering stable asset identities and ingesting already-available local
/// subtitle sidecars. No cloud call is required.
class LibraryIntelligenceIndexer {
  LibraryIntelligenceIndexer({
    required this.mediaRepository,
    required this.assets,
    required this.transcripts,
    required this.ingest,
    required this.contentSegments,
    required this.embeddings,
  });

  final MediaRepository mediaRepository;
  final IntelligenceAssetRepository assets;
  final TranscriptService transcripts;
  final SubtitleIngestService ingest;
  final ContentSegmentService contentSegments;
  final LocalEmbeddingService embeddings;

  Future<LibraryIndexProgress> indexLibrary({
    int limit = 200,
    void Function(int done, int total)? onProgress,
  }) async {
    final media = await mediaRepository.browse(deduplicateShows: false);
    final targets = media.take(limit).toList(growable: false);
    var indexed = 0;
    var withTranscripts = 0;
    var skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < targets.length; i++) {
      onProgress?.call(i, targets.length);
      try {
        final result = await indexMedia(targets[i]);
        if (result == null) {
          skipped += 1;
        } else {
          indexed += 1;
          if (result > 0) withTranscripts += 1;
        }
      } catch (error) {
        errors.add('${targets[i].title}: $error');
      }
    }
    onProgress?.call(targets.length, targets.length);
    return LibraryIndexProgress(
      scanned: targets.length,
      indexed: indexed,
      withTranscripts: withTranscripts,
      skipped: skipped,
      errors: errors,
    );
  }

  /// Returns transcript line count when indexed, or null when skipped.
  Future<int?> indexMedia(Media media) async {
    final path = _localPath(media);
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;

    final identity = await MediaIdentityService.fromFile(
      path: path,
      fileHash: media.fileHash,
    );
    await assets.upsert(
      identity: identity,
      mediaId: media.id,
      status: 'indexed',
    );

    final existing = await transcripts.getByAsset(identity.identityKey);
    var segmentCount = existing.length;
    if (segmentCount == 0) {
      final sidecars = await ExternalSubtitleFinder.findFor(path);
      if (sidecars.isEmpty) {
        await contentSegments.rebuildFromTranscripts(identity.identityKey);
        await embeddings.rebuildFromTranscripts(identity.identityKey);
        return 0;
      }
      final preferred = sidecars.first;
      segmentCount = await ingest.ingestFile(
        assetId: identity.identityKey,
        path: preferred.path,
        language: preferred.languageHint ?? '',
      );
    }

    await contentSegments.rebuildFromTranscripts(identity.identityKey);
    await embeddings.rebuildFromTranscripts(identity.identityKey);
    return segmentCount;
  }

  Future<Map<String, int>> statusCounts() async {
    final media = await mediaRepository.browse(deduplicateShows: false);
    final allAssets = await assets.list(limit: 100000);
    var withMedia = 0;
    for (final asset in allAssets) {
      if (asset.mediaId != null && asset.mediaId!.isNotEmpty) withMedia += 1;
    }
    // Distinct assets that already have at least one transcript line.
    final transcriptAssets = <String>{};
    for (final asset in allAssets.take(500)) {
      final segments = await transcripts.getByAsset(asset.id);
      if (segments.isNotEmpty) transcriptAssets.add(asset.id);
    }
    return {
      'libraryItems': media.length,
      'intelligenceAssets': allAssets.length,
      'linkedAssets': withMedia,
      'assetsWithTranscripts': transcriptAssets.length,
    };
  }

  String? _localPath(Media media) {
    final raw = (media.fullPath?.trim().isNotEmpty == true)
        ? media.fullPath!.trim()
        : media.path.trim();
    if (raw.isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) {
      if (parsed.scheme == 'file') return parsed.toFilePath();
      return null;
    }
    return raw;
  }
}
