import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/intelligence/ai_worker_client.dart';

void main() {
  test('matches JSONL progress and result messages by request id', () async {
    final transport = FakeWorkerTransport();
    final client = AiWorkerClient(transport);
    final progress = <double>[];

    final resultFuture = client.request(
      'transcribe',
      {'path': '/tmp/movie.mkv'},
      onProgress: progress.add,
    );
    final request = await transport.sentLines.first;
    final requestId = jsonDecode(request)['id'] as String;
    transport.emit(jsonEncode({'id': requestId, 'type': 'progress', 'progress': 0.5}));
    transport.emit(jsonEncode({
      'id': requestId,
      'type': 'result',
      'result': {'segments': []},
    }));

    expect(await resultFuture, {'segments': []});
    expect(progress, [0.5]);
    await client.close();
  });

  test('surfaces worker errors as typed exceptions', () async {
    final transport = FakeWorkerTransport();
    final client = AiWorkerClient(transport);
    final resultFuture = client.request('probe', {'path': '/tmp/movie.mkv'});
    final request = await transport.sentLines.first;
    final requestId = jsonDecode(request)['id'] as String;
    transport.emit(jsonEncode({
      'id': requestId,
      'type': 'error',
      'error': {'message': 'ffprobe unavailable'},
    }));

    await expectLater(resultFuture, throwsA(isA<AiWorkerException>()));
    await client.close();
  });
}

class FakeWorkerTransport implements WorkerTransport {
  final _incoming = StreamController<String>.broadcast();
  final sent = StreamController<String>();

  Stream<String> get sentLines => sent.stream;

  @override
  Stream<String> get lines => _incoming.stream;

  @override
  Future<void> send(String line) async => sent.add(line);

  void emit(String line) => _incoming.add(line);

  @override
  Future<void> close() async {
    await _incoming.close();
    await sent.close();
  }
}
