import '../../data/intelligence/intelligence_models.dart';
import 'content_segment_service.dart';

class SmartSkipMarker {
  const SmartSkipMarker({
    required this.kind,
    required this.startMs,
    required this.endMs,
    required this.label,
  });

  final String kind;
  final int startMs;
  final int endMs;
  final String label;
}

/// Derives intro/outro skip windows from content-segment heuristics.
class SmartSkipService {
  const SmartSkipService(this._contentSegments);

  final ContentSegmentService _contentSegments;

  Future<List<SmartSkipMarker>> markersFor(String assetId) async {
    final segments = await _contentSegments.listByAsset(assetId);
    if (segments.isEmpty) return const [];
    final markers = <SmartSkipMarker>[];
    for (final segment in segments) {
      final marker = _fromSegment(segment);
      if (marker != null) markers.add(marker);
    }
    return markers;
  }

  SmartSkipMarker? activeMarker({
    required List<SmartSkipMarker> markers,
    required int positionMs,
  }) {
    for (final marker in markers) {
      if (positionMs >= marker.startMs && positionMs < marker.endMs - 1500) {
        return marker;
      }
    }
    return null;
  }

  SmartSkipMarker? _fromSegment(ContentSegment segment) {
    final title = segment.title.toLowerCase();
    if (title.contains('intro') ||
        title.contains('opening') ||
        title.contains('recap')) {
      return SmartSkipMarker(
        kind: 'intro',
        startMs: segment.startMs,
        endMs: segment.endMs,
        label: '跳过片头',
      );
    }
    if (title.contains('end credits') || title.contains('closing')) {
      return SmartSkipMarker(
        kind: 'outro',
        startMs: segment.startMs,
        endMs: segment.endMs,
        label: '跳过片尾',
      );
    }
    return null;
  }
}
