import 'dart:async';

import 'package:flutter/services.dart';

class PlaybackAudioTrack {
  const PlaybackAudioTrack({required this.id, this.title, this.language});

  factory PlaybackAudioTrack.no() =>
      const PlaybackAudioTrack(id: '-1', title: 'Disabled');

  final String id;
  final String? title;
  final String? language;
}

class PlaybackSubtitleTrack {
  const PlaybackSubtitleTrack({
    required this.id,
    this.title,
    this.language,
    this.uri = false,
  });

  factory PlaybackSubtitleTrack.no() =>
      const PlaybackSubtitleTrack(id: '-1', title: 'Disabled');

  factory PlaybackSubtitleTrack.uri(
    String uri, {
    String? title,
    String? language,
  }) => PlaybackSubtitleTrack(
    id: uri,
    title: title,
    language: language,
    uri: true,
  );

  final String id;
  final String? title;
  final String? language;
  final bool uri;
}

class PlaybackTracks {
  const PlaybackTracks({required this.audio, required this.subtitle});

  final List<PlaybackAudioTrack> audio;
  final List<PlaybackSubtitleTrack> subtitle;
}

class _PendingOpen {
  const _PendingOpen({required this.uri, this.startAt, this.httpHeaders});

  final String uri;
  final Duration? startAt;
  final Map<String, String>? httpHeaders;
}

enum PlaybackVideoEvent { tap, doubleTap }

/// Native VLC playback service.
///
/// macOS uses an AppKit platform view backed by VLCKit. Windows uses a native
/// child window backed by libVLC. Both runners expose the same method channel.
class PlaybackService {
  static const _channel = MethodChannel('com.openfilmly.vlc_player');

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _bufferController = StreamController<Duration>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _tracksController = StreamController<PlaybackTracks>.broadcast();
  final _videoEventController =
      StreamController<PlaybackVideoEvent>.broadcast();

  int? _viewId;
  _PendingOpen? _pendingOpen;
  Timer? _pollTimer;
  bool _refreshing = false;
  bool _disposed = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _completed = false;
  bool _buffering = true;
  double _volume = 100;
  double _rate = 1.0;
  List<PlaybackAudioTrack> _audioTracks = const [];
  List<PlaybackSubtitleTrack> _subtitleTracks = const [];
  PlaybackAudioTrack _currentAudioTrack = PlaybackAudioTrack.no();
  PlaybackSubtitleTrack _currentSubtitleTrack = PlaybackSubtitleTrack.no();

  PlaybackService() {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  PlaybackStreams get player => PlaybackStreams(
    position: _positionController.stream,
    duration: _durationController.stream,
    playing: _playingController.stream,
    completed: _completedController.stream,
    volume: _volumeController.stream,
    buffer: _bufferController.stream,
    buffering: _bufferingController.stream,
    error: _errorController.stream,
    tracks: _tracksController.stream,
  );

  Stream<PlaybackVideoEvent> get videoEvents => _videoEventController.stream;

  Future<void> attachNativeView(int viewId) async {
    _viewId = viewId;
    final pending = _pendingOpen;
    if (pending != null) {
      await _openAttached(pending);
    }
    _startPolling();
  }

  /// Updates the Windows VLC child-window bounds. The macOS platform view
  /// manages its own layout and never calls this method.
  Future<void> setNativeBounds(
    Rect bounds, {
    required double devicePixelRatio,
  }) async {
    final viewId = _viewId;
    if (viewId == null) return;
    await _channel.invokeMethod<void>('setBounds', {
      'viewId': viewId,
      'x': (bounds.left * devicePixelRatio).round(),
      'y': (bounds.top * devicePixelRatio).round(),
      'width': (bounds.width * devicePixelRatio).round(),
      'height': (bounds.height * devicePixelRatio).round(),
    });
  }

  /// Opens [uri] (a local file path or an http:// URL) and starts playback.
  /// Optionally resumes from [startAt]. [httpHeaders] are forwarded to the
  /// native VLC bridge when supported by libVLC.
  Future<void> open(
    String uri, {
    Duration? startAt,
    Map<String, String>? httpHeaders,
  }) async {
    _buffering = true;
    if (!_disposed) _bufferingController.add(true);
    final pending = _PendingOpen(
      uri: uri,
      startAt: startAt,
      httpHeaders: httpHeaders,
    );
    _pendingOpen = pending;
    if (_viewId != null) {
      await _openAttached(pending);
    }
  }

  Future<void> playOrPause() => _invoke('playOrPause');

  Future<void> seek(Duration position) async {
    await _invoke('seek', {'positionMs': position.inMilliseconds});
    _position = position;
    _positionController.add(position);
  }

  /// Volume is expressed on a 0-100 scale.
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 100.0);
    await _invoke('setVolume', {'volume': clamped.round()});
    _volume = clamped;
    _volumeController.add(clamped);
  }

  /// Set playback speed (1.0 = normal, 0.5 = half, 2.0 = double).
  Future<void> setRate(double rate) async {
    final clamped = rate.clamp(0.25, 4.0);
    await _invoke('setRate', {'rate': clamped});
    _rate = clamped;
  }

  List<PlaybackAudioTrack> get audioTracks => _audioTracks;

  List<PlaybackSubtitleTrack> get subtitleTracks => _subtitleTracks;

  PlaybackAudioTrack get currentAudioTrack => _currentAudioTrack;

  PlaybackSubtitleTrack get currentSubtitleTrack => _currentSubtitleTrack;

  Future<void> setAudioTrack(PlaybackAudioTrack track) =>
      _invoke('setAudioTrack', {'trackId': int.tryParse(track.id) ?? -1});

  Future<void> setSubtitleTrack(PlaybackSubtitleTrack track) async {
    if (track.uri) {
      try {
        await _invoke('addSubtitleTrack', {'uri': track.id});
      } on MissingPluginException {
        // The current Windows libVLC bridge supports embedded subtitle tracks
        // but does not expose runtime sidecar attachment yet.
        return;
      }
      _currentSubtitleTrack = track;
      _tracksController.add(
        PlaybackTracks(audio: _audioTracks, subtitle: _subtitleTracks),
      );
      return;
    }
    await _invoke('setSubtitleTrack', {
      'trackId': int.tryParse(track.id) ?? -1,
    });
    _currentSubtitleTrack = track;
  }

  double get rate => _rate;

  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    unawaited(_invoke('dispose'));
    _positionController.close();
    _durationController.close();
    _playingController.close();
    _completedController.close();
    _volumeController.close();
    _bufferController.close();
    _bufferingController.close();
    _errorController.close();
    _tracksController.close();
    _videoEventController.close();
  }

  Future<void> _openAttached(_PendingOpen pending) async {
    await _invoke('open', {
      'uri': pending.uri,
      'startMs': pending.startAt?.inMilliseconds ?? 0,
      'httpHeaders': pending.httpHeaders ?? const <String, String>{},
    });
    _startPolling();
  }

  Future<Object?> _handleNativeEvent(MethodCall call) async {
    if (_disposed) return null;
    final args = call.arguments;
    if (args is Map) {
      final nativeViewId = _asInt(args['viewId']);
      if (_viewId != null && nativeViewId != null && nativeViewId != _viewId) {
        return null;
      }
    }

    switch (call.method) {
      case 'videoTap':
        _videoEventController.add(PlaybackVideoEvent.tap);
      case 'videoDoubleClick':
        _videoEventController.add(PlaybackVideoEvent.doubleTap);
    }
    return null;
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_refresh()),
    );
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_disposed || _viewId == null || _refreshing) return;
    _refreshing = true;
    try {
      await _refreshStatus();
      await _refreshTracks();
    } on MissingPluginException {
      // Ignore on platforms without a native VLC bridge.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshStatus() async {
    final status = await _invokeMap('status');
    final position = Duration(milliseconds: _asInt(status['positionMs']) ?? 0);
    final duration = Duration(milliseconds: _asInt(status['durationMs']) ?? 0);
    final playing = status['playing'] == true;
    final completed = status['completed'] == true;
    final volume = (_asNum(status['volume']) ?? 100).toDouble();
    final rate = (_asNum(status['rate']) ?? 1).toDouble();
    final buffer = Duration(milliseconds: _asInt(status['bufferMs']) ?? 0);
    final buffering = status['buffering'] == true;
    final error = status['error'] as String?;

    if (position != _position) {
      _position = position;
      if (!_disposed) _positionController.add(position);
    }
    if (duration != _duration) {
      _duration = duration;
      if (!_disposed) _durationController.add(duration);
    }
    if (playing != _playing) {
      _playing = playing;
      if (!_disposed) _playingController.add(playing);
    }
    if (completed != _completed) {
      _completed = completed;
      if (!_disposed) _completedController.add(completed);
    }
    if (volume != _volume) {
      _volume = volume;
      if (!_disposed) _volumeController.add(volume);
    }
    if (!_disposed) _bufferController.add(buffer);
    if (buffering != _buffering) {
      _buffering = buffering;
      if (!_disposed) _bufferingController.add(buffering);
    }
    if (error != null && error.isNotEmpty && !_disposed) {
      _errorController.add(error);
    }
    _rate = rate;
  }

  Future<void> _refreshTracks() async {
    final tracks = await _invokeMap('tracks');
    final audio = _trackList(
      tracks['audio'],
      (track) => PlaybackAudioTrack(
        id: track.id,
        title: track.title,
        language: track.language,
      ),
    );
    final subtitle = _trackList(
      tracks['subtitle'],
      (track) => PlaybackSubtitleTrack(
        id: track.id,
        title: track.title,
        language: track.language,
      ),
    );
    final currentAudioId = '${_asInt(tracks['currentAudio']) ?? -1}';
    final currentSubtitleId = '${_asInt(tracks['currentSubtitle']) ?? -1}';

    final tracksChanged =
        !_sameAudioTracks(_audioTracks, audio) ||
        !_sameSubtitleTracks(_subtitleTracks, subtitle);
    _audioTracks = audio;
    _subtitleTracks = subtitle;
    _currentAudioTrack = audio.firstWhere(
      (track) => track.id == currentAudioId,
      orElse: PlaybackAudioTrack.no,
    );
    _currentSubtitleTrack = subtitle.firstWhere(
      (track) => track.id == currentSubtitleId,
      orElse: PlaybackSubtitleTrack.no,
    );
    if (tracksChanged && !_disposed) {
      _tracksController.add(
        PlaybackTracks(audio: _audioTracks, subtitle: _subtitleTracks),
      );
    }
  }

  bool _sameAudioTracks(
    List<PlaybackAudioTrack> a,
    List<PlaybackAudioTrack> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].language != b[i].language) {
        return false;
      }
    }
    return true;
  }

  bool _sameSubtitleTracks(
    List<PlaybackSubtitleTrack> a,
    List<PlaybackSubtitleTrack> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].language != b[i].language) {
        return false;
      }
    }
    return true;
  }

  Future<void> _invoke(String method, [Map<String, Object?> args = const {}]) {
    final viewId = _viewId;
    if (viewId == null) return Future.value();
    return _channel.invokeMethod<void>(method, {'viewId': viewId, ...args});
  }

  Future<Map<Object?, Object?>> _invokeMap(String method) async {
    final viewId = _viewId;
    if (viewId == null) return const {};
    final result = await _channel.invokeMethod<Object?>(method, {
      'viewId': viewId,
    });
    if (result is Map) {
      return Map<Object?, Object?>.from(result);
    }
    return const {};
  }

  List<T> _trackList<T>(Object? value, T Function(_NativeTrack track) build) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<Object?, Object?>.from(item))
        .map((item) {
          final id = '${item['id'] ?? '-1'}';
          return build(
            _NativeTrack(
              id: id,
              title: item['title'] as String?,
              language: _emptyAsNull(item['language'] as String?),
            ),
          );
        })
        .toList(growable: false);
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  num? _asNum(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  String? _emptyAsNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

class PlaybackStreams {
  const PlaybackStreams({
    required this.position,
    required this.duration,
    required this.playing,
    required this.completed,
    required this.volume,
    required this.buffer,
    required this.buffering,
    required this.error,
    required this.tracks,
  });

  final Stream<Duration> position;
  final Stream<Duration> duration;
  final Stream<bool> playing;
  final Stream<bool> completed;
  final Stream<double> volume;
  final Stream<Duration> buffer;
  final Stream<bool> buffering;
  final Stream<String> error;
  final Stream<PlaybackTracks> tracks;

  PlaybackStreams get stream => this;
}

class _NativeTrack {
  const _NativeTrack({required this.id, this.title, this.language});

  final String id;
  final String? title;
  final String? language;
}
