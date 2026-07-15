import 'media.dart';
import 'playback_progress.dart';

/// Library item paired with its latest playback progress snapshot.
class ContinueWatchingItem {
  const ContinueWatchingItem({required this.media, required this.progress});

  final Media media;
  final PlaybackProgress progress;
}
