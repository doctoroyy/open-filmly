import '../../data/intelligence/intelligence_models.dart';

class SpoilerGuardService {
  const SpoilerGuardService();

  List<TranscriptSegment> visibleBefore(
    Iterable<TranscriptSegment> segments,
    int positionMs,
  ) {
    return segments
        .where((segment) => segment.endMs <= positionMs)
        .toList(growable: false);
  }
}
