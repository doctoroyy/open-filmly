import 'ai_worker_client.dart';

typedef WorkerTransportStarter = Future<WorkerTransport> Function();

/// Owns the lifetime of the local AI worker and its JSONL client.
///
/// The manager is deliberately independent of Flutter so it can be tested in
/// isolation and reused by the macOS runtime. A single worker is shared by all
/// AI tasks; callers never start a second process for a concurrent request.
class AiWorkerManager {
  AiWorkerManager({required this._startTransport});

  final WorkerTransportStarter _startTransport;
  AiWorkerClient? _client;
  Future<AiWorkerClient>? _starting;
  var _closed = false;

  Future<AiWorkerClient> client() async {
    if (_closed) {
      throw const AiWorkerException('Worker manager is closed');
    }
    final current = _client;
    if (current != null) return current;
    final starting = _starting;
    if (starting != null) return starting;
    final future = _start();
    _starting = future;
    try {
      final created = await future;
      _client = created;
      return created;
    } finally {
      _starting = null;
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> input, {
    void Function(double progress)? onProgress,
    bool retryOnce = true,
  }) async {
    try {
      return await (await client()).request(
        method,
        input,
        onProgress: onProgress,
      );
    } on AiWorkerException {
      if (!retryOnce || _closed) rethrow;
      await restart();
      return (await client()).request(method, input, onProgress: onProgress);
    }
  }

  Future<void> restart() async {
    final current = _client;
    _client = null;
    if (current != null) await current.close();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final current = _client;
    _client = null;
    if (current != null) await current.close();
  }

  Future<AiWorkerClient> _start() async {
    final transport = await _startTransport();
    return AiWorkerClient(transport);
  }
}
