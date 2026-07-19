import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/smb/smb_proxy_server.dart';
import 'package:open_filmly/services/streaming/range_source.dart';

/// In-memory [RangeSource] backed by a fixed byte buffer. Lets us exercise the
/// proxy's HTTP Range math end-to-end (real socket, real HttpClient) without a
/// live SMB server — the part of the M2 "命门" we can verify deterministically.
class _MemorySource implements RangeSource {
  _MemorySource(this.data);

  final Uint8List data;
  final readCalls = <_ReadCall>[];

  @override
  Future<int> length(String id) async => data.length;

  @override
  Future<Stream<List<int>>> read(String id, int start, int endInclusive) async {
    // endInclusive is inclusive, matching the SmbService contract.
    readCalls.add(_ReadCall(start, endInclusive));
    return Stream.value(data.sublist(start, endInclusive + 1));
  }
}

class _ReadCall {
  const _ReadCall(this.start, this.endInclusive);

  final int start;
  final int endInclusive;
}

void main() {
  late SmbProxyServer proxy;
  late _MemorySource source;
  late Uint8List data;
  late String url;
  final client = HttpClient();

  setUp(() async {
    data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
    source = _MemorySource(data);
    proxy = SmbProxyServer(source, initialResponseBytes: 128);
    await proxy.start();
    url = proxy.urlFor('any/movie.mkv');
  });

  tearDown(() async {
    await proxy.stop();
  });

  Future<HttpClientResponse> request(
    String urlString, {
    String? range,
    String method = 'GET',
  }) async {
    final uri = Uri.parse(urlString);
    final req = method == 'HEAD'
        ? await client.headUrl(uri)
        : await client.getUrl(uri);
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    return req.close();
  }

  test('HEAD returns stream metadata without reading the SMB body', () async {
    final res = await request(url, method: 'HEAD');
    expect(res.statusCode, 200);
    expect(res.headers.value(HttpHeaders.contentLengthHeader), '1000');
    expect(res.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
    expect(source.readCalls, isEmpty);
    await res.drain<void>();
  });

  test('no Range header → 200 with full body', () async {
    data = Uint8List.fromList(List.generate(100, (i) => i % 256));
    source = _MemorySource(data);
    await proxy.stop();
    proxy = SmbProxyServer(source, initialResponseBytes: 128);
    await proxy.start();
    url = proxy.urlFor('any/small.mp4');

    final res = await request(url);
    expect(res.statusCode, 200);
    expect(res.headers.value(HttpHeaders.contentLengthHeader), '100');
    expect(res.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
    final bytes = await _collect(res);
    expect(bytes, equals(data));
  });

  test('large no Range GET returns full body (MKV-safe)', () async {
    final res = await request(url);
    expect(res.statusCode, 200);
    expect(res.headers.value(HttpHeaders.contentRangeHeader), isNull);
    expect(res.headers.value(HttpHeaders.contentLengthHeader), '1000');
    expect(res.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
    final bytes = await _collect(res);
    expect(bytes, equals(data));
    expect(source.readCalls.single.start, 0);
    expect(source.readCalls.single.endInclusive, 999);
  });

  test('Range bytes=0-99 → 206 partial content', () async {
    final res = await request(url, range: 'bytes=0-99');
    expect(res.statusCode, 206);
    expect(
      res.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 0-99/1000',
    );
    expect(res.headers.value(HttpHeaders.contentLengthHeader), '100');
    final bytes = await _collect(res);
    expect(bytes, equals(data.sublist(0, 100)));
  });

  test('mid-file Range bytes=500-599 → correct slice', () async {
    final res = await request(url, range: 'bytes=500-599');
    expect(res.statusCode, 206);
    expect(
      res.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 500-599/1000',
    );
    final bytes = await _collect(res);
    expect(bytes, equals(data.sublist(500, 600)));
  });

  test('open-ended Range bytes=900- → tail to EOF', () async {
    final res = await request(url, range: 'bytes=900-');
    expect(res.statusCode, 206);
    expect(
      res.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 900-999/1000',
    );
    expect(res.headers.value(HttpHeaders.contentLengthHeader), '100');
    final bytes = await _collect(res);
    expect(bytes, equals(data.sublist(900, 1000)));
  });

  test('suffix Range bytes=-100 → last 100 bytes', () async {
    final res = await request(url, range: 'bytes=-100');
    expect(res.statusCode, 206);
    expect(
      res.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 900-999/1000',
    );
    expect(res.headers.value(HttpHeaders.contentLengthHeader), '100');
    final bytes = await _collect(res);
    expect(bytes, equals(data.sublist(900, 1000)));
    expect(source.readCalls.single.start, 900);
    expect(source.readCalls.single.endInclusive, 999);
  });

  test('unsatisfiable Range bytes=5000- → 416', () async {
    final res = await request(url, range: 'bytes=5000-');
    expect(res.statusCode, 416);
    expect(res.headers.value(HttpHeaders.contentRangeHeader), 'bytes */1000');
    await res.drain<void>();
  });

  test('malformed Range → 416 instead of a proxy error', () async {
    final res = await request(url, range: 'bytes=abc-def');
    expect(res.statusCode, 416);
    expect(res.headers.value(HttpHeaders.contentRangeHeader), 'bytes */1000');
    await res.drain<void>();
  });

  test('unknown token → 404', () async {
    final res = await request('http://127.0.0.1:${proxy.port}/stream/999999');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test(
    'subtitle URL preserves extension and returns subtitle MIME type',
    () async {
      final subtitleUrl = proxy.urlFor(
        'any/movie.chs.srt',
        displayName: 'movie.chs.srt',
      );
      expect(Uri.parse(subtitleUrl).path, endsWith('/movie.chs.srt'));

      final res = await request(subtitleUrl);
      expect(
        res.headers.value(HttpHeaders.contentTypeHeader),
        'application/x-subrip; charset=utf-8',
      );
      await res.drain<void>();
    },
  );

  test('serves normalized in-memory subtitles with Range support', () async {
    final subtitle = Uint8List.fromList('Chinese subtitle'.codeUnits);
    final subtitleUrl = proxy.urlForBytes(
      subtitle,
      displayName: 'movie.zh-CN.srt',
    );
    final res = await request(subtitleUrl, range: 'bytes=8-15');
    expect(res.statusCode, 206);
    expect(
      res.headers.value(HttpHeaders.contentTypeHeader),
      'application/x-subrip; charset=utf-8',
    );
    expect(await _collect(res), subtitle.sublist(8, 16));
  });
}

Future<Uint8List> _collect(HttpClientResponse res) async {
  final builder = BytesBuilder();
  await for (final chunk in res) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
