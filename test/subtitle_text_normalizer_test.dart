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
