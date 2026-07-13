import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../streaming/range_source.dart';

/// Local HTTP proxy that streams a [RangeSource] (SMB today) to VLC over
/// HTTP, translating HTTP Range requests into ranged reads. This is what makes
/// seeking work while keeping playback on VLC's reliable `http://` path.
///
/// Binds to loopback only. Source ids are mapped to opaque tokens so the real
/// path never appears in the URL handed to the player.
class SmbProxyServer {
  SmbProxyServer(this._source, {this.initialResponseBytes = 32 * 1024 * 1024});

  static const _rangePrefix = 'bytes=';

  final RangeSource _source;
  final int initialResponseBytes;
  HttpServer? _server;
  final Map<String, String> _pathByToken = {};
  final Map<String, String> _tokenByPath = {};
  final Map<String, Uint8List> _bytesByToken = {};
  final Map<String, String> _contentTypeByToken = {};
  int _counter = 0;

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// Starts the proxy on an ephemeral loopback port. Idempotent.
  Future<void> start() async {
    if (_server != null) return;
    _server = await shelf_io.serve(_handle, InternetAddress.loopbackIPv4, 0);
  }

  /// Registers [sourceId] for streaming and returns a loopback URL that
  /// media_kit can play.
  String urlFor(String sourceId, {String? displayName}) {
    final token = _tokenByPath[sourceId] ?? (++_counter).toString();
    _pathByToken[token] = sourceId;
    _tokenByPath[sourceId] = token;
    final suffix = displayName == null || displayName.isEmpty
        ? ''
        : '/${Uri.encodeComponent(displayName)}';
    return 'http://127.0.0.1:${port!}/stream/$token$suffix';
  }

  /// Registers a small in-memory resource, primarily a subtitle normalized to
  /// UTF-8. It uses the same loopback origin as video so libVLC can load it
  /// without SMB/WebDAV credentials or platform-specific charset handling.
  String urlForBytes(
    List<int> bytes, {
    required String displayName,
    String? contentType,
  }) {
    final token = 'memory-${++_counter}';
    _bytesByToken[token] = Uint8List.fromList(bytes);
    _contentTypeByToken[token] = contentType ?? _contentType(displayName);
    return 'http://127.0.0.1:${port!}/stream/$token/'
        '${Uri.encodeComponent(displayName)}';
  }

  Future<Response> _handle(Request request) async {
    final segments = request.url.pathSegments;
    if ((segments.length != 2 && segments.length != 3) ||
        segments.first != 'stream') {
      return Response.notFound('Not found');
    }
    final token = segments[1];
    final memory = _bytesByToken[token];
    if (memory != null) {
      return _handleMemory(request, token, memory);
    }

    final sourceId = _pathByToken[token];
    if (sourceId == null) {
      return Response.notFound('Unknown token');
    }

    try {
      final total = await _source.length(sourceId);

      var start = 0;
      var end = total - 1;
      var statusCode = 200;
      final requestedRange = _parseRange(
        request.headers[HttpHeaders.rangeHeader],
        total,
      );
      final hasRange = requestedRange != null;
      if (requestedRange != null) {
        start = requestedRange.start;
        end = requestedRange.end;
        statusCode = 206;
      } else if (request.method.toUpperCase() == 'GET' &&
          total > initialResponseBytes) {
        end = initialResponseBytes - 1;
        statusCode = 206;
      }

      if (hasRange && total == 0) return _rangeNotSatisfiable(total);
      if (total > 0 && (start < 0 || start >= total || start > end)) {
        return _rangeNotSatisfiable(total);
      }
      if (end > total - 1) end = total - 1;
      final length = total == 0 ? 0 : end - start + 1;

      final headers = {
        'Content-Type': _contentType(sourceId),
        'Accept-Ranges': 'bytes',
        'Content-Length': '$length',
        if (statusCode == 206) 'Content-Range': 'bytes $start-$end/$total',
      };
      if (request.method.toUpperCase() == 'HEAD' || length == 0) {
        return Response(statusCode, headers: headers);
      }

      final body = await _source.read(sourceId, start, end);
      return Response(statusCode, body: body, headers: headers);
    } on FormatException {
      final total = await _source.length(sourceId);
      return _rangeNotSatisfiable(total);
    } catch (e) {
      return Response.internalServerError(body: 'Stream read error: $e');
    }
  }

  Response _handleMemory(Request request, String token, Uint8List data) {
    try {
      final total = data.length;
      var start = 0;
      var end = total - 1;
      var statusCode = 200;
      final requestedRange = _parseRange(
        request.headers[HttpHeaders.rangeHeader],
        total,
      );
      if (requestedRange != null) {
        start = requestedRange.start;
        end = requestedRange.end;
        statusCode = 206;
      }
      if (requestedRange != null && total == 0) {
        return _rangeNotSatisfiable(total);
      }
      if (total > 0 && (start < 0 || start >= total || start > end)) {
        return _rangeNotSatisfiable(total);
      }
      if (end > total - 1) end = total - 1;
      final length = total == 0 ? 0 : end - start + 1;
      final headers = {
        'Content-Type':
            _contentTypeByToken[token] ?? 'application/octet-stream',
        'Accept-Ranges': 'bytes',
        'Content-Length': '$length',
        if (statusCode == 206) 'Content-Range': 'bytes $start-$end/$total',
      };
      if (request.method.toUpperCase() == 'HEAD' || length == 0) {
        return Response(statusCode, headers: headers);
      }
      return Response(
        statusCode,
        body: Stream<List<int>>.value(data.sublist(start, end + 1)),
        headers: headers,
      );
    } on FormatException {
      return _rangeNotSatisfiable(data.length);
    }
  }

  _ByteRange? _parseRange(String? header, int total) {
    if (header == null || header.isEmpty) return null;
    if (!header.startsWith(_rangePrefix)) {
      throw const FormatException('Unsupported range unit');
    }

    final spec = header.substring(_rangePrefix.length).split(',').first.trim();
    final dash = spec.indexOf('-');
    if (dash < 0) throw const FormatException('Invalid range');

    final startText = spec.substring(0, dash).trim();
    final endText = spec.substring(dash + 1).trim();
    if (startText.isEmpty && endText.isEmpty) {
      throw const FormatException('Invalid range');
    }

    if (startText.isEmpty) {
      final suffixLength = int.tryParse(endText);
      if (suffixLength == null || suffixLength <= 0) {
        throw const FormatException('Invalid suffix range');
      }
      if (total == 0) return const _ByteRange(0, -1);
      final length = math.min(suffixLength, total);
      return _ByteRange(total - length, total - 1);
    }

    final start = int.tryParse(startText);
    final explicitEnd = endText.isEmpty ? null : int.tryParse(endText);
    if (start == null ||
        start < 0 ||
        (endText.isNotEmpty && explicitEnd == null)) {
      throw const FormatException('Invalid range');
    }

    final end = explicitEnd ?? total - 1;
    if (end < start) throw const FormatException('Invalid range');
    return _ByteRange(start, math.min(end, total - 1));
  }

  Response _rangeNotSatisfiable(int total) {
    return Response(416, headers: {'Content-Range': 'bytes */$total'});
  }

  String _contentType(String sourceId) {
    final lower = sourceId.toLowerCase();
    if (lower.endsWith('.srt')) return 'application/x-subrip; charset=utf-8';
    if (lower.endsWith('.ass') || lower.endsWith('.ssa')) {
      return 'text/x-ssa; charset=utf-8';
    }
    if (lower.endsWith('.vtt')) return 'text/vtt; charset=utf-8';
    if (lower.endsWith('.sub')) return 'text/plain; charset=utf-8';
    return 'application/octet-stream';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _pathByToken.clear();
    _tokenByPath.clear();
    _bytesByToken.clear();
    _contentTypeByToken.clear();
  }
}

class _ByteRange {
  const _ByteRange(this.start, this.end);

  final int start;
  final int end;
}
