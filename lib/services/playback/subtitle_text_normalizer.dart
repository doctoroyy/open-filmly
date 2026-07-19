import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

/// Converts common Chinese subtitle encodings to UTF-8 before handing them to
/// libVLC. This avoids Android rendering replacement boxes for GBK/GB18030
/// sidecar subtitles while leaving valid UTF-8 content unchanged.
class SubtitleTextNormalizer {
  const SubtitleTextNormalizer._();

  static Uint8List toUtf8(List<int> input) {
    if (input.isEmpty) return Uint8List(0);
    final bytes = input is Uint8List ? input : Uint8List.fromList(input);
    final text = _decode(bytes);
    return Uint8List.fromList(utf8.encode(text));
  }

  static String _decode(Uint8List bytes) {
    if (_startsWith(bytes, const [0xEF, 0xBB, 0xBF])) {
      return utf8.decode(bytes.sublist(3), allowMalformed: false);
    }
    if (_startsWith(bytes, const [0xFF, 0xFE])) {
      return _decodeUtf16(bytes, 2, Endian.little);
    }
    if (_startsWith(bytes, const [0xFE, 0xFF])) {
      return _decodeUtf16(bytes, 2, Endian.big);
    }

    // Prefer strict UTF-8. Chinese sidecars are commonly GBK/GB18030 and will
    // fail this decode, then fall through to the multi-byte Chinese codecs.
    try {
      final asUtf8 = utf8.decode(bytes, allowMalformed: false);
      // A "valid" UTF-8 decode of pure ASCII timestamps is fine; if the body
      // already has CJK it is almost certainly real UTF-8.
      if (!_looksLikeMojibake(asUtf8)) return asUtf8;
    } on FormatException {
      // Fall through to GBK/GB18030.
    }

    try {
      final asGbk = gbk.decode(bytes, allowMalformed: false);
      if (asGbk.isNotEmpty) return asGbk;
    } catch (_) {
      // Fall through.
    }

    return gbk.decode(bytes, allowMalformed: true);
  }

  /// Heuristic for Latin-1 misreads of Chinese text (rare when UTF-8 is strict,
  /// but guards against mixed files that still decode without throwing).
  static bool _looksLikeMojibake(String text) {
    if (text.isEmpty) return false;
    // Replacement char is a hard signal of prior bad decoding.
    if (text.contains('\uFFFD')) return true;
    final cjk = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    if (cjk > 0) return false;
    // Lots of high Latin-1 / private-use code points with almost no CJK is a
    // classic GBK-as-Latin1 signature in subtitle bodies.
    final highLatin = RegExp(
      r'[\u00a0-\u00ff\u0400-\u04ff]',
    ).allMatches(text).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
    return highLatin >= 8 && highLatin > letters;
  }

  static String _decodeUtf16(Uint8List bytes, int offset, Endian endian) {
    final usableLength = (bytes.length - offset) & ~1;
    final data = ByteData.sublistView(bytes, offset, offset + usableLength);
    final codeUnits = <int>[];
    for (var index = 0; index < usableLength; index += 2) {
      codeUnits.add(data.getUint16(index, endian));
    }
    return String.fromCharCodes(codeUnits);
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }
}
