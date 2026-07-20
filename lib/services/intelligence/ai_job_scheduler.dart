import 'dart:async';

import '../../data/intelligence/ai_job_repository.dart';
import 'ai_job_service.dart';

/// Persistent serial scheduler for AI work.
///
/// It deliberately owns no UI state. A wake-up drains queued jobs until the
/// database has no runnable work, so a process restart can call `start` and
/// continue where the previous runtime stopped.
class AiJobScheduler {
  AiJobScheduler(AiJobRepository repository)
    : _service = AiJobService(repository);

  final AiJobService _service;
  AiJobHandler? _handler;
  Future<void>? _draining;
  var _started = false;

  Future<void> start(AiJobHandler handler) async {
    _handler = handler;
    _started = true;
    await wake();
  }

  Future<void> wake() async {
    if (!_started || _handler == null) return;
    final current = _draining;
    if (current != null) return current;
    final future = _drain();
    _draining = future;
    try {
      await future;
    } finally {
      _draining = null;
    }
  }

  Future<void> stop() async {
    _started = false;
    await _draining;
    _handler = null;
  }

  Future<void> recoverAndWake() async {
    await _service.recoverAfterRestart();
    await wake();
  }

  Future<void> _drain() async {
    final handler = _handler;
    if (handler == null) return;
    while (_started) {
      final job = await _service.runNext(handler);
      if (job == null) break;
    }
  }
}
