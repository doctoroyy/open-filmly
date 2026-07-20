import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_models.dart';
import 'package:open_filmly/services/intelligence/spoiler_guard_service.dart';

void main() {
  test('only exposes segments that ended before the current position', () {
    const segments = [
      TranscriptSegment(
        id: 'before',
        assetId: 'asset',
        startMs: 0,
        endMs: 1000,
        text: 'before',
        language: 'en',
      ),
      TranscriptSegment(
        id: 'current',
        assetId: 'asset',
        startMs: 1000,
        endMs: 2000,
        text: 'current',
        language: 'en',
      ),
      TranscriptSegment(
        id: 'future',
        assetId: 'asset',
        startMs: 2000,
        endMs: 3000,
        text: 'future',
        language: 'en',
      ),
    ];

    final visible = SpoilerGuardService().visibleBefore(segments, 2000);

    expect(visible.map((segment) => segment.id), ['before', 'current']);
  });
}
