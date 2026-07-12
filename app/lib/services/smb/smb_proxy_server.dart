import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../streaming/range_source.dart';

/// Local HTTP proxy that streams a [RangeSource] (SMB today) to media_kit over
/// HTTP, translating HTTP Range requests into ranged reads. This is what makes
/// seeking work, and keeps libmpv on the rock-solid `http://` code path
/// instead of relying on smb:// support in the bundled build.
///
/// Binds to loopback only. Source ids are mapped to opaque tokens so the real
/// path never appears in the URL handed to the player.
class SmbProxyServer {
  SmbProxyServer(this._source);

  final RangeSource _source;
  HttpServer? _server;
  final Map<String, String> _pathByToken = {};
  final Map<String, String> _tokenByPath = {};
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

  Future<Response> _handle(Request request) async {
    final segments = request.url.pathSegments;
    if ((segments.length != 2 && segments.length != 3) ||
        segments.first != 'stream') {
      return Response.notFound('Not found');
    }
    final sourceId = _pathByToken[segments[1]];
    if (sourceId == null) {
      return Response.notFound('Unknown token');
    }

    try {
      final total = await _source.length(sourceId);

      var start = 0;
      var end = total - 1; // inclusive
      final range = request.headers['range'];
      final hasRange = range != null && range.startsWith('bytes=');
      if (hasRange) {
        final spec = range.substring(6).split('-');
        if (spec[0].isNotEmpty) start = int.parse(spec[0]);
        if (spec.length > 1 && spec[1].isNotEmpty) end = int.parse(spec[1]);
      }

      if (total > 0 && (start < 0 || start >= total || start > end)) {
        return Response(416, headers: {'Content-Range': 'bytes */$total'});
      }
      if (end > total - 1) end = total - 1;
      final length = end - start + 1;

      final body = await _source.read(sourceId, start, end);
      final headers = {
        'Content-Type': _contentType(sourceId),
        'Accept-Ranges': 'bytes',
        'Content-Length': '$length',
        if (hasRange) 'Content-Range': 'bytes $start-$end/$total',
      };
      return Response(hasRange ? 206 : 200, body: body, headers: headers);
    } catch (e) {
      return Response.internalServerError(body: 'Stream read error: $e');
    }
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
  }
}
