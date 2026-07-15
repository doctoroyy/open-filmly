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

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return gbk.decode(bytes, allowMalformed: true);
    }
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
