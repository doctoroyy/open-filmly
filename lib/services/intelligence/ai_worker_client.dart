import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract interface class WorkerTransport {
  Stream<String> get lines;

  Future<void> send(String line);

  Future<void> close();
}

class AiWorkerException implements Exception {
  const AiWorkerException(this.message);

  final String message;

  @override
  String toString() => 'AiWorkerException: $message';
}

class ProcessWorkerTransport implements WorkerTransport {
  ProcessWorkerTransport._(this._process) {
    _stdoutSubscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_lines.add, onError: _lines.addError, onDone: _lines.close);
  }

  final Process _process;
  final _lines = StreamController<String>.broadcast();
  late final StreamSubscription<String> _stdoutSubscription;

  static Future<ProcessWorkerTransport> start(
    String executable, {
    List<String> arguments = const [],
  }) async {
    final process = await Process.start(executable, arguments);
    return ProcessWorkerTransport._(process);
  }

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> send(String line) async {
    _process.stdin.writeln(line);
    await _process.stdin.flush();
  }

  @override
  Future<void> close() async {
    await _stdoutSubscription.cancel();
    await _lines.close();
    _process.kill();
  }
}

class AiWorkerClient {
  AiWorkerClient(this._transport) {
    _subscription = _transport.lines.listen(
      _handleLine,
      onError: _failPending,
      onDone: () => _failPending(const AiWorkerException('Worker exited')),
    );
  }

  final WorkerTransport _transport;
  late final StreamSubscription<String> _subscription;
  final _pending = <String, _PendingRequest>{};
  var _counter = 0;
  var _closed = false;

  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> input, {
    void Function(double progress)? onProgress,
  }) {
    if (_closed) {
      return Future.error(const AiWorkerException('Worker client is closed'));
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    final pending = _PendingRequest(onProgress);
    _pending[id] = pending;
    unawaited(
      _transport.send(
        jsonEncode({'id': id, 'method': method, 'input': input}),
      ),
    );
    return pending.completer.future;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    final error = const AiWorkerException('Worker client is closed');
    for (final pending in _pending.values) {
      pending.completer.completeError(error);
    }
    _pending.clear();
    await _transport.close();
  }

  void _handleLine(String line) {
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return;
      message = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    final id = message['id']?.toString();
    if (id == null) return;
    final pending = _pending[id];
    if (pending == null) return;
    switch (message['type']) {
      case 'progress':
        final value = (message['progress'] as num?)?.toDouble();
        if (value != null) pending.onProgress?.call(value.clamp(0, 1));
        break;
      case 'result':
        _pending.remove(id);
        pending.completer.complete(
          Map<String, dynamic>.from(message['result'] as Map? ?? const {}),
        );
        break;
      case 'error':
        _pending.remove(id);
        final error = message['error'];
        final text = error is Map
            ? error['message']?.toString() ?? 'Unknown worker error'
            : error?.toString() ?? 'Unknown worker error';
        pending.completer.completeError(AiWorkerException(text));
        break;
    }
  }

  void _failPending(Object error, [StackTrace? stackTrace]) {
    final exception = error is AiWorkerException
        ? error
        : AiWorkerException(error.toString());
    for (final pending in _pending.values) {
      pending.completer.completeError(exception, stackTrace);
    }
    _pending.clear();
  }
}

class _PendingRequest {
  _PendingRequest(this.onProgress);

  final void Function(double progress)? onProgress;
  final completer = Completer<Map<String, dynamic>>();
}
