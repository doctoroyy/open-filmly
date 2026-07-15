import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/playback/external_subtitle_finder.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('filmly_subs_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> touch(String name) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsString('1\n00:00:01,000 --> 00:00:02,000\nok\n');
    return file;
  }

  test(
    'finds exact-stem and language-tagged sidecars next to a local video',
    () async {
      final video = await touch('The.Matrix.1999.mkv');
      await touch('The.Matrix.1999.srt');
      await touch('The.Matrix.1999.chs.ass');
      await touch('The.Matrix.1999.en.srt');
      await touch('Other.Movie.srt'); // different stem — ignore

      final found = await ExternalSubtitleFinder.findFor(video.path);
      expect(found.map((f) => p.basename(f.path)).toSet(), {
        'The.Matrix.1999.srt',
        'The.Matrix.1999.chs.ass',
        'The.Matrix.1999.en.srt',
      });
      // Chinese variants rank first.
      expect(
        found.first.languageHint,
        anyOf('chs', 'zh', 'zh-cn', 'chi', 'cn', 'sc'),
      );
      expect(found.first.uri, startsWith('file://'));
    },
  );

  test('matches network sibling paths without changing their location', () {
    final found = ExternalSubtitleFinder.findAmongSiblings(
      '/Media/Movies/Dune.2021.mkv',
      const [
        '/Media/Movies/Dune.2021.zh-CN.srt',
        '/Media/Movies/Dune.2021.en.ass',
        '/Media/Movies/Other.srt',
      ],
    );

    expect(found, hasLength(2));
    expect(found.first.path, '/Media/Movies/Dune.2021.zh-CN.srt');
    expect(found.first.languageHint, 'zh-cn');
  });

  test('skips http sources', () async {
    final found = await ExternalSubtitleFinder.findFor(
      'http://127.0.0.1:8080/proxy/movie.mkv',
    );
    expect(found, isEmpty);
  });

  test('isChineseHint covers common tags', () {
    expect(ExternalSubtitleFinder.isChineseHint('chs'), isTrue);
    expect(ExternalSubtitleFinder.isChineseHint('zh-CN'), isTrue);
    expect(ExternalSubtitleFinder.isChineseHint('en'), isFalse);
  });
}
