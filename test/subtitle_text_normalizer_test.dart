import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/playback/subtitle_text_normalizer.dart';

void main() {
  test('keeps valid UTF-8 Chinese subtitles readable', () {
    final normalized = SubtitleTextNormalizer.toUtf8(
      utf8.encode('1\n00:00:01,000 --> 00:00:02,000\n你好，世界'),
    );
    expect(utf8.decode(normalized), contains('你好，世界'));
  });

  test('converts GBK subtitles to UTF-8', () {
    final normalized = SubtitleTextNormalizer.toUtf8(
      gbk.encode('1\n00:00:01,000 --> 00:00:02,000\n中文字幕'),
    );
    expect(utf8.decode(normalized), contains('中文字幕'));
  });

  test('converts real-world GBK documentary credits without mojibake', () {
    // Sample from 权力的游戏_征服与反抗 sidecar (GBK, CRLF).
    final gbkBytes = gbk.encode(
      '1\r\n00:00:02,730 --> 00:00:07,650\r\n哈里·劳埃德，饰\r\n韦赛里斯·坦格利安\r\n',
    );
    final normalized = SubtitleTextNormalizer.toUtf8(gbkBytes);
    final text = utf8.decode(normalized);
    expect(text, contains('哈里'));
    expect(text, contains('坦格利安'));
    expect(text, isNot(contains('Ð')));
    expect(text, isNot(contains('\uFFFD')));
  });

  test('converts UTF-16 little endian subtitles to UTF-8', () {
    const text = '字幕测试';
    final data = ByteData(2 + text.codeUnits.length * 2)
      ..setUint8(0, 0xFF)
      ..setUint8(1, 0xFE);
    for (var index = 0; index < text.codeUnits.length; index++) {
      data.setUint16(2 + index * 2, text.codeUnitAt(index), Endian.little);
    }
    final normalized = SubtitleTextNormalizer.toUtf8(data.buffer.asUint8List());
    expect(utf8.decode(normalized), text);
  });
}
