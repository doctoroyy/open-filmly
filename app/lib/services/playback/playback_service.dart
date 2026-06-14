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
  const PlaybackSubtitleTrack({required this.id, this.title, this.language});

  factory PlaybackSubtitleTrack.no() =>
      const PlaybackSubtitleTrack(id: '-1', title: 'Disabled');

  final String id;
  final String? title;
  final String? language;
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
/// On macOS the video output is an AppKit platform view backed by VLCKit.
/// On Windows the runner creates a native child window backed by libVLC.
/// Playback commands and status polling go through the same method channel.
class PlaybackService {
  static const _channel = MethodChannel('com.openfilmly.vlc_player');

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
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

  /// Updates the native Windows VLC child-window bounds. No-op on macOS.
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

  Future<void> setSubtitleTrack(PlaybackSubtitleTrack track) =>
      _invoke('setSubtitleTrack', {'trackId': int.tryParse(track.id) ?? -1});

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
      // Ignore on platforms without the native VLC bridge.
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
  });

  final Stream<Duration> position;
  final Stream<Duration> duration;
  final Stream<bool> playing;
  final Stream<bool> completed;
  final Stream<double> volume;

  PlaybackStreams get stream => this;
}

class _NativeTrack {
  const _NativeTrack({required this.id, this.title, this.language});

  final String id;
  final String? title;
  final String? language;
}
