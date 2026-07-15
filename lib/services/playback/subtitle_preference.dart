import 'external_subtitle_finder.dart';
import 'playback_service.dart';

/// The subtitle track selected automatically for a newly opened media item.
class PreferredSubtitleSelection {
  PreferredSubtitleSelection.embedded(PlaybackSubtitleTrack track)
    : embedded = track,
      external = null,
      key = 'embedded:${track.id}';

  PreferredSubtitleSelection.external(ExternalSubtitleFile file)
    : embedded = null,
      external = file,
      key = 'external:${file.path}';

  final PlaybackSubtitleTrack? embedded;
  final ExternalSubtitleFile? external;
  final String key;
}

/// Ranks embedded and sidecar subtitles using language and title metadata.
class SubtitlePreference {
  SubtitlePreference._();

  static PreferredSubtitleSelection? choose({
    required List<PlaybackSubtitleTrack> embedded,
    required List<ExternalSubtitleFile> external,
  }) {
    final candidates = <_SubtitleCandidate>[
      for (final file in external)
        _SubtitleCandidate(
          selection: PreferredSubtitleSelection.external(file),
          score: _score(
            language: file.languageHint,
            title: file.label,
            external: true,
          ),
        ),
      for (final track in embedded)
        if (track.id != '-1' &&
            track.id != 'no' &&
            track.id != 'auto' &&
            !track.uri)
          _SubtitleCandidate(
            selection: PreferredSubtitleSelection.embedded(track),
            score: _score(
              language: track.language,
              title: track.title,
              external: false,
            ),
          ),
    ];

    candidates.removeWhere((candidate) => candidate.score <= 0);
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.selection;
  }

  static int _score({
    required String? language,
    required String? title,
    required bool external,
  }) {
    final metadata = '${language ?? ''} ${title ?? ''}'.toLowerCase();
    final compact = metadata.replaceAll(RegExp(r'[\s_.-]+'), '');

    final simplified = _containsAny(compact, const [
      'chs',
      'zhcn',
      'zhhans',
      'hans',
      'sc',
      'simplified',
      '简体',
      '简中',
    ]);
    if (simplified) return external ? 420 : 400;

    final chinese = _containsAny(compact, const [
      'cht',
      'zhtw',
      'zhhant',
      'hant',
      'tc',
      'traditional',
      '繁体',
      '繁中',
      '中文',
      'chinese',
      'chi',
      'zho',
      'zh',
    ]);
    if (chinese) return external ? 320 : 300;

    // Keep the existing behavior of loading a same-directory sidecar when no
    // Chinese option exists, but do not replace player defaults with an
    // arbitrary embedded language.
    return external ? 100 : 0;
  }

  static bool _containsAny(String value, List<String> hints) {
    return hints.any(value.contains);
  }
}

class _SubtitleCandidate {
  const _SubtitleCandidate({required this.selection, required this.score});

  final PreferredSubtitleSelection selection;
  final int score;
}
