import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/playback/external_subtitle_finder.dart';
import 'package:open_filmly/services/playback/playback_service.dart';
import 'package:open_filmly/services/playback/subtitle_preference.dart';

void main() {
  test('prefers simplified Chinese embedded track over English tracks', () {
    final selected = SubtitlePreference.choose(
      embedded: const [
        PlaybackSubtitleTrack(id: '5', language: 'eng'),
        PlaybackSubtitleTrack(id: '6', title: '繁体', language: 'chi'),
        PlaybackSubtitleTrack(id: '8', title: '简体', language: 'chi'),
      ],
      external: const [],
    );

    expect(selected?.embedded?.id, '8');
  });

  test('prefers simplified Chinese sidecar over embedded Chinese track', () {
    final selected = SubtitlePreference.choose(
      embedded: const [
        PlaybackSubtitleTrack(id: '8', title: '简体', language: 'chi'),
      ],
      external: const [
        ExternalSubtitleFile(
          path: '/tmp/movie.chs.srt',
          label: 'movie.chs.srt',
          languageHint: 'chs',
        ),
      ],
    );

    expect(selected?.external?.path, '/tmp/movie.chs.srt');
  });

  test('does not let an English sidecar override embedded Chinese', () {
    final selected = SubtitlePreference.choose(
      embedded: const [
        PlaybackSubtitleTrack(id: '8', title: '简体', language: 'chi'),
      ],
      external: const [
        ExternalSubtitleFile(
          path: '/tmp/movie.en.srt',
          label: 'movie.en.srt',
          languageHint: 'en',
        ),
      ],
    );

    expect(selected?.embedded?.id, '8');
  });

  test('keeps sidecar fallback when no Chinese subtitle exists', () {
    final selected = SubtitlePreference.choose(
      embedded: const [PlaybackSubtitleTrack(id: '5', language: 'eng')],
      external: const [
        ExternalSubtitleFile(
          path: '/tmp/movie.en.srt',
          label: 'movie.en.srt',
          languageHint: 'en',
        ),
      ],
    );

    expect(selected?.external?.path, '/tmp/movie.en.srt');
  });

  test('leaves arbitrary embedded languages to the player default', () {
    final selected = SubtitlePreference.choose(
      embedded: const [
        PlaybackSubtitleTrack(id: 'no'),
        PlaybackSubtitleTrack(id: 'auto'),
        PlaybackSubtitleTrack(id: '5', language: 'eng'),
      ],
      external: const [],
    );

    expect(selected, isNull);
  });
}
