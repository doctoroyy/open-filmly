import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/intelligence/ai_worker_client.dart';
import 'package:open_filmly/services/intelligence/ai_worker_manager.dart';

void main() {
  test('starts one client and recreates it after restart', () async {
    final transports = <_FakeWorkerTransport>[];
    final manager = AiWorkerManager(
      startTransport: () async {
        final transport = _FakeWorkerTransport();
        transports.add(transport);
        return transport;
      },
    );

    final first = await manager.client();
    expect(await manager.client(), same(first));
    expect(transports, hasLength(1));

    await manager.restart();
    final second = await manager.client();
    expect(second, isNot(same(first)));
    expect(transports, hasLength(2));

    await manager.close();
  });

  test('restarts a failed request once before surfacing the error', () async {
    var starts = 0;
    final manager = AiWorkerManager(
      startTransport: () async {
        starts++;
        return _FakeWorkerTransport(respondToRequests: true);
      },
    );

    final result = await manager.request('probe', {'path': '/tmp/movie.mkv'});

    expect(result, {'ok': true});
    expect(starts, 1);
    await manager.close();
  });
}

class _FakeWorkerTransport implements WorkerTransport {
  _FakeWorkerTransport({this.respondToRequests = false});

  final bool respondToRequests;
  final _incoming = StreamController<String>.broadcast();
  final _sent = StreamController<String>();

  Stream<String> get sentLines => _sent.stream;

  @override
  Stream<String> get lines => _incoming.stream;

  @override
  Future<void> send(String line) async {
    _sent.add(line);
    if (!respondToRequests) return;
    _incoming.add(
      '{"id":"${line.split('"id":"')[1].split('"')[0]}","type":"result","result":{"ok":true}}',
    );
  }

  @override
  Future<void> close() async {
    await _incoming.close();
    await _sent.close();
  }
}
