import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/desktop_window.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/platform/window_channel.dart';
import '../../data/models/episode.dart';
import '../../data/models/playback_progress.dart';
import '../../data/repositories/playback_progress_repository.dart';
import '../../providers/data_providers.dart';
import '../../services/library/media_library_entry_factory.dart';
import '../../providers/smb_providers.dart';
import '../../services/playback/external_subtitle_finder.dart';
import '../../services/playback/playback_service.dart';
import '../../services/playback/playback_source_resolver.dart';
import '../../services/playback/subtitle_preference.dart';
import '../../services/playback/vlc_video_view.dart';

/// Arguments passed to [PlayerPage] via go_router's `extra`.
class PlayerArgs {
  const PlayerArgs({
    required this.uri,
    required this.title,
    this.mediaId,
    this.startAt,
    this.httpHeaders,
    this.subtitles = const [],
    this.showId,
    this.showTitle,
  });

  /// Local file path or http:// stream URL.
  final String uri;
  final String title;
  final String? mediaId;
  final Duration? startAt;

  /// Optional HTTP headers (e.g. WebDAV Basic auth) for the source.
  final Map<String, String>? httpHeaders;

  /// Sidecar subtitle URLs discovered while resolving SMB or WebDAV media.
  final List<PlaybackSubtitleSource> subtitles;

  /// Parent TV show id — enables prev/next episode + auto-play next.
  final String? showId;
  final String? showTitle;
}

/// Full-screen player backed by native VLCKit with a NetEase-style control layer.
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, required this.args});

  final PlayerArgs args;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _persistInterval = Duration(seconds: 5);
  static const _controlsHideDelay = Duration(seconds: 3);
  static const _skipStep = Duration(seconds: 10);
  static const _autoNextDelay = Duration(seconds: 5);
  static const _nativeTopControlsReserve = 82.0;
  static const _nativeBottomControlsReserve = 138.0;
  static const _nativeBottomSheetReserve = 430.0;
  /// Quick presets shown as chips; continuous speed is adjusted via slider.
  static const _speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
  static const _minRate = 0.25;
  static const _maxRate = 4.0;
  static const _rateStep = 0.1;
  static const _accent = Color(0xFF2F6BFF);
  /// Baomihua-like muted control grey.
  static const _chromeFg = Color(0xFFE8E8E8);
  static const _chromeDim = Color(0xFFB0B0B0);

  late final PlaybackService _playback;
  final FocusNode _focusNode = FocusNode();

  late String _uri;
  late String _title;
  String? _mediaId;
  Map<String, String>? _httpHeaders;
  late List<PlaybackSubtitleSource> _networkSubtitles;

  PlaybackProgressRepository? _progressRepo;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<PlaybackTracks>? _tracksSub;
  StreamSubscription<PlaybackVideoEvent>? _videoEventSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  Duration _lastPersistedPosition = Duration.zero;
  bool _completed = false;
  bool _playing = true;
  bool _buffering = true;
  bool _controlsVisible = true;
  bool _optionSheetVisible = false;
  bool _dragging = false;
  bool _opening = true;
  String? _error;
  double _volume = 100;
  double _volumeBeforeMute = 100;
  bool _muted = false;
  double _rate = 1.0;
  bool _alwaysOnTop = false;
  /// Displayed like Baomihua top-right transfer rate (KB/s or MB/s).
  double _transferBytesPerSec = 0;
  DateTime? _speedSampleAt;
  Duration _speedSampleBuffer = Duration.zero;
  Timer? _hideTimer;
  Timer? _toastTimer;
  Timer? _autoNextTimer;
  Timer? _speedSampleTimer;
  String? _toast;
  int _autoNextSeconds = 0;

  List<Episode> _episodes = const [];
  int _episodeIndex = -1;
  List<ExternalSubtitleFile> _externalSubs = const [];
  bool _externalSubsLoaded = false;
  String? _autoSubtitleKey;
  bool _applyingSubtitlePreference = false;
  bool _subtitlePreferencePending = false;

  @override
  void initState() {
    super.initState();
    _playback = PlaybackService();
    _uri = widget.args.uri;
    _title = widget.args.title;
    _mediaId = widget.args.mediaId;
    _httpHeaders = widget.args.httpHeaders;
    _networkSubtitles = widget.args.subtitles;
    _position = widget.args.startAt ?? Duration.zero;
    _lastPersistedPosition = _position;

    if (_mediaId != null) {
      _progressRepo = ref.read(playbackProgressRepositoryProvider);
    }
    _bindStreams();
    _videoEventSub = _playback.videoEvents.listen(_handleNativeVideoEvent);
    _configurePlatformPlayback();
    unawaited(_openCurrent(startAt: widget.args.startAt));
    unawaited(_loadEpisodePlaylist());
    _scheduleHideControls();
    _speedSampleTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _sampleTransferRate(),
    );
  }

  @override
  void dispose() {
    _restorePlatformAfterPlayback();
    _hideTimer?.cancel();
    _toastTimer?.cancel();
    _autoNextTimer?.cancel();
    _speedSampleTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _volumeSub?.cancel();
    _errorSub?.cancel();
    _tracksSub?.cancel();
    _videoEventSub?.cancel();
    _focusNode.dispose();
    _playback.dispose();
    super.dispose();
  }

  void _configurePlatformPlayback() {
    if (PlatformCapabilities.isDesktop) {
      // Desktop player is a full-window chrome (Baomihua-style), not a
      // navigated page with a back stack affordance.
      unawaited(DesktopWindow.setTitle(_title));
      return;
    }
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  void _restorePlatformAfterPlayback() {
    if (PlatformCapabilities.isDesktop) {
      unawaited(DesktopWindow.setAlwaysOnTop(false));
      unawaited(DesktopWindow.setTitle('Open Filmly'));
      return;
    }
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  void _sampleTransferRate() {
    if (!mounted) return;
    final now = DateTime.now();
    final prevAt = _speedSampleAt;
    final prevBuf = _speedSampleBuffer;
    _speedSampleAt = now;
    _speedSampleBuffer = _buffer;
    if (prevAt == null) return;
    final dt = now.difference(prevAt).inMilliseconds;
    if (dt <= 0) return;
    // Rough estimate from buffered media advance (network streams). Local
    // files stay at 0 so the UI can hide or show idle.
    final isNetwork = _uri.startsWith('http://') || _uri.startsWith('https://');
    if (!isNetwork) {
      if (_transferBytesPerSec != 0) {
        setState(() => _transferBytesPerSec = 0);
      }
      return;
    }
    final dBufMs = (_buffer - prevBuf).inMilliseconds;
    if (dBufMs <= 0) {
      if (_buffering || _opening) {
        setState(() => _transferBytesPerSec = 0);
      }
      return;
    }
    // Assume ~8 Mbps equivalent media bitrate for display purposes when we
    // only know buffered duration growth.
    const assumedBitsPerSecond = 8 * 1000 * 1000;
    final bytes = (dBufMs / 1000.0) * (assumedBitsPerSecond / 8.0);
    final bps = bytes / (dt / 1000.0);
    setState(() => _transferBytesPerSec = bps.clamp(0, 200 * 1024 * 1024));
  }

  String _formatTransferRate() {
    if (_buffering || _opening) return '0 KB/s';
    final bps = _transferBytesPerSec;
    if (bps <= 0) {
      final isNetwork =
          _uri.startsWith('http://') || _uri.startsWith('https://');
      return isNetwork ? '0 KB/s' : '';
    }
    if (bps >= 1024 * 1024) {
      return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bps / 1024).toStringAsFixed(0)} KB/s';
  }

  Future<void> _toggleAlwaysOnTop() async {
    final next = !_alwaysOnTop;
    await DesktopWindow.setAlwaysOnTop(next);
    if (!mounted) return;
    setState(() => _alwaysOnTop = next);
    _showToast(next ? '窗口置顶' : '取消置顶');
  }

  Future<void> _openCurrent({Duration? startAt}) async {
    setState(() {
      _opening = true;
      _buffering = true;
      _error = null;
      _completed = false;
      _externalSubs = const [];
      _externalSubsLoaded = false;
      _autoSubtitleKey = null;
      _cancelAutoNext();
    });
    try {
      await _playback.open(_uri, startAt: startAt, httpHeaders: _httpHeaders);
      if (!mounted) return;
      setState(() => _opening = false);
      unawaited(_loadExternalSubtitles());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _buffering = false;
        _error = '无法打开媒体：$e';
      });
    }
  }

  Future<void> _loadEpisodePlaylist() async {
    final showId = widget.args.showId;
    if (showId == null || showId.isEmpty) return;
    try {
      final episodes = await ref
          .read(episodeRepositoryProvider)
          .getByShow(showId);
      if (!mounted) return;
      final idx = _mediaId == null
          ? -1
          : episodes.indexWhere((e) => e.id == _mediaId);
      setState(() {
        _episodes = episodes;
        _episodeIndex = idx;
      });
    } catch (_) {
      // Playlist is best-effort.
    }
  }

  Future<void> _loadExternalSubtitles() async {
    try {
      final local = await ExternalSubtitleFinder.findFor(_uri);
      final found = [
        ...local,
        for (final subtitle in _networkSubtitles)
          ExternalSubtitleFile(
            path: subtitle.uri,
            label: subtitle.title,
            languageHint: subtitle.language,
          ),
      ];
      if (!mounted) return;
      setState(() {
        _externalSubs = found;
        _externalSubsLoaded = true;
      });
      await _applyPreferredSubtitle();
    } catch (_) {
      if (mounted) setState(() => _externalSubsLoaded = true);
    }
  }

  void _bindStreams() {
    _positionSub = _playback.player.stream.position.listen((position) {
      if (!mounted || _dragging) return;
      setState(() => _position = position);
      if ((position - _lastPersistedPosition).abs() >= _persistInterval) {
        unawaited(_persistProgress());
      }
    });
    _durationSub = _playback.player.stream.duration.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _bufferSub = _playback.player.stream.buffer.listen((buffer) {
      if (!mounted) return;
      setState(() => _buffer = buffer);
    });
    _playingSub = _playback.player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _playing = playing);
      if (playing) _scheduleHideControls();
    });
    _bufferingSub = _playback.player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      setState(() => _buffering = buffering);
    });
    _volumeSub = _playback.player.stream.volume.listen((volume) {
      if (!mounted) return;
      setState(() {
        _volume = volume;
        _muted = volume <= 0;
      });
    });
    _errorSub = _playback.player.stream.error.listen((message) {
      if (!mounted || message.trim().isEmpty) return;
      setState(() {
        _error = message;
        _opening = false;
        _buffering = false;
      });
    });
    _completedSub = _playback.player.stream.completed.listen((completed) {
      _completed = completed;
      if (completed) {
        unawaited(_persistProgress(force: true));
        if (_hasNextEpisode) {
          _startAutoNextCountdown();
        } else {
          _showToast('播放完毕');
          _showControls();
        }
      }
    });
    _tracksSub = _playback.player.stream.tracks.listen((_) {
      if (!mounted) return;
      setState(() {});
      unawaited(_applyPreferredSubtitle());
    });
  }

  Future<void> _applyPreferredSubtitle() async {
    if (!mounted) return;
    if (_applyingSubtitlePreference) {
      _subtitlePreferencePending = true;
      return;
    }

    _applyingSubtitlePreference = true;
    try {
      do {
        _subtitlePreferencePending = false;
        final selected = SubtitlePreference.choose(
          embedded: _playback.subtitleTracks,
          external: _externalSubs,
        );
        if (selected == null || selected.key == _autoSubtitleKey) continue;

        final external = selected.external;
        if (external != null) {
          await _playback.setSubtitleTrack(
            PlaybackSubtitleTrack.uri(
              external.uri,
              title: external.label,
              language: external.languageHint,
            ),
          );
        } else {
          await _playback.setSubtitleTrack(selected.embedded!);
        }
        _autoSubtitleKey = selected.key;
      } while (_subtitlePreferencePending && mounted);
    } catch (_) {
      // Subtitle preference is best-effort and must never block playback.
    } finally {
      _applyingSubtitlePreference = false;
    }
  }

  bool get _hasNextEpisode =>
      _episodeIndex >= 0 && _episodeIndex < _episodes.length - 1;

  bool get _hasPrevEpisode => _episodeIndex > 0;

  Episode? get _nextEpisode =>
      _hasNextEpisode ? _episodes[_episodeIndex + 1] : null;

  Future<void> _persistProgress({bool force = false}) async {
    final mediaId = _mediaId;
    final repo = _progressRepo;
    if (mediaId == null || repo == null) return;

    final snapshot = PlaybackProgress.capture(
      mediaId: mediaId,
      position: _position,
      duration: _duration,
      completed: _completed,
    );

    if (snapshot == null) {
      if (force) {
        await repo.clear(mediaId);
        if (mounted) _invalidateProgress(mediaId);
      }
      return;
    }

    _lastPersistedPosition = snapshot.position;
    await repo.save(snapshot);
    if (mounted) _invalidateProgress(mediaId);
  }

  void _invalidateProgress(String mediaId) {
    ref.invalidate(playbackProgressByMediaIdProvider(mediaId));
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(recentlyWatchedMediaProvider);
  }

  Future<void> _handleBack() async {
    _cancelAutoNext();
    await _persistProgress(force: true);
    if (!mounted) return;
    context.pop();
  }

  // --- Control interactions ----------------------------------------------

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_controlsHideDelay, () {
      if (mounted && _playing && !_dragging && _error == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _handleNativeVideoEvent(PlaybackVideoEvent event) {
    switch (event) {
      case PlaybackVideoEvent.tap:
        _toggleControls();
      case PlaybackVideoEvent.doubleTap:
        unawaited(DesktopWindow.toggleFullScreen());
    }
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _togglePlay() async {
    _cancelAutoNext();
    await _playback.playOrPause();
    _showControls();
  }

  Future<void> _skip(Duration delta) async {
    _cancelAutoNext();
    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
              ? _duration
              : target);
    await _playback.seek(clamped);
    setState(() => _position = clamped);
    final secs = delta.inSeconds.abs();
    _showToast(delta.isNegative ? '−${secs}s' : '+${secs}s');
    _showControls();
  }

  Future<void> _setRate(double rate) async {
    final clamped = double.parse(
      rate.clamp(_minRate, _maxRate).toStringAsFixed(2),
    );
    await _playback.setRate(clamped);
    setState(() => _rate = clamped);
    _showToast(_formatRate(clamped));
  }

  Future<void> _nudgeRate(double delta) async {
    await _setRate(_rate + delta);
    _showControls();
  }

  String _formatRate(double rate) {
    final text = rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2);
    return '${text.replaceAll(RegExp(r'\.00$'), '')}x';
  }

  Future<void> _setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 100.0);
    await _playback.setVolume(clamped);
    setState(() {
      _volume = clamped;
      _muted = clamped <= 0;
      if (clamped > 0) _volumeBeforeMute = clamped;
    });
  }

  Future<void> _toggleMute() async {
    if (_muted || _volume <= 0) {
      final restore = _volumeBeforeMute > 0 ? _volumeBeforeMute : 100.0;
      await _setVolume(restore);
      _showToast('取消静音');
    } else {
      _volumeBeforeMute = _volume;
      await _setVolume(0);
      _showToast('静音');
    }
    _showControls();
  }

  void _startAutoNextCountdown() {
    _cancelAutoNext();
    setState(() => _autoNextSeconds = _autoNextDelay.inSeconds);
    _showControls();
    _autoNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_autoNextSeconds <= 1) {
        timer.cancel();
        unawaited(_playAdjacentEpisode(1));
      } else {
        setState(() => _autoNextSeconds -= 1);
      }
    });
  }

  void _cancelAutoNext() {
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
    if (_autoNextSeconds != 0 && mounted) {
      setState(() => _autoNextSeconds = 0);
    } else {
      _autoNextSeconds = 0;
    }
  }

  Future<void> _playAdjacentEpisode(int delta) async {
    _cancelAutoNext();
    final targetIndex = _episodeIndex + delta;
    if (targetIndex < 0 || targetIndex >= _episodes.length) return;

    final showId = widget.args.showId;
    if (showId == null) return;

    await _persistProgress(force: true);

    final episode = _episodes[targetIndex];
    try {
      setState(() {
        _opening = true;
        _error = null;
      });
      final show = await ref.read(mediaByIdProvider(showId).future);
      if (show == null) {
        throw StateError('找不到剧集所属的媒体条目');
      }
      final playable = MediaLibraryEntryFactory.episodePlayableMedia(
        episode,
        show,
      );
      final source = await ref
          .read(playbackSourceResolverProvider)
          .resolve(playable);
      if (!mounted) return;

      setState(() {
        _uri = source.uri;
        _httpHeaders = source.httpHeaders;
        _networkSubtitles = source.subtitles;
        _mediaId = episode.id;
        _title =
            '${widget.args.showTitle ?? show.title} - ${episode.displayLabel}';
        _episodeIndex = targetIndex;
        _position = Duration.zero;
        _duration = Duration.zero;
        _buffer = Duration.zero;
        _lastPersistedPosition = Duration.zero;
        _progressRepo = ref.read(playbackProgressRepositoryProvider);
      });
      await _openCurrent();
      _showToast(delta > 0 ? '下一集' : '上一集');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = '切换剧集失败：$e';
      });
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      unawaited(_togglePlay());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_skip(-_skipStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_skip(_skipStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      unawaited(_setVolume(_volume + 10));
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      unawaited(_setVolume(_volume - 10));
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF ||
        key == LogicalKeyboardKey.f11 ||
        (key == LogicalKeyboardKey.enter &&
            HardwareKeyboard.instance.isAltPressed)) {
      unawaited(DesktopWindow.toggleFullScreen());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      unawaited(_toggleMute());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyN) {
      if (_hasNextEpisode) unawaited(_playAdjacentEpisode(1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP) {
      if (_hasPrevEpisode) unawaited(_playAdjacentEpisode(-1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketLeft) {
      unawaited(_nudgeRate(-_rateStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketRight) {
      unawaited(_nudgeRate(_rateStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      unawaited(_handleBack());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: MouseRegion(
          onHover: (_) => _showControls(),
          cursor: PlatformCapabilities.isDesktop && !_controlsVisible
              ? SystemMouseCursors.none
              : MouseCursor.defer,
          child: Stack(
            children: [
              Positioned.fill(
                child: VlcVideoView(
                  service: _playback,
                  nativeOverlayInsets: _nativeOverlayInsets,
                ),
              ),
              // Desktop (VLC / nPlayer): whole surface single-click toggles
              // chrome, double-click toggles fullscreen. Mobile keeps the
              // left/center/right seek + play zones.
              if (PlatformCapabilities.isDesktop)
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('player_desktop_gesture'),
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () =>
                        unawaited(DesktopWindow.toggleFullScreen()),
                  ),
                )
              else
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _toggleControls,
                          onDoubleTap: () => _skip(-_skipStep),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          key: const Key('player_center_gesture'),
                          behavior: HitTestBehavior.translucent,
                          onTap: _toggleControls,
                          onDoubleTap: _togglePlay,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _toggleControls,
                          onDoubleTap: () => _skip(_skipStep),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_buffering || _opening) _bufferingOverlay(),
              if (_error != null) _errorOverlay(),
              if (_toast != null) _toastOverlay(),
              if (_autoNextSeconds > 0) _autoNextOverlay(),
              _controlsOverlay(context),
              if (PlatformCapabilities.isDesktop)
                Positioned(
                  top: 0,
                  left: PlatformCapabilities.isMacOS
                      ? WindowChromeMetrics.macOSTrafficLightReservedWidth
                      : 0,
                  right: 0,
                  height: WindowChromeMetrics.macOSTitlebarHeight,
                  child: const DragToMoveArea(child: SizedBox.expand()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets get _nativeOverlayInsets {
    if (!PlatformCapabilities.isWindows) return EdgeInsets.zero;
    final top = _controlsVisible ? _nativeTopControlsReserve : 0.0;
    final bottom = _optionSheetVisible
        ? _nativeBottomSheetReserve
        : (_controlsVisible ? _nativeBottomControlsReserve : 0.0);
    return EdgeInsets.only(top: top, bottom: bottom);
  }

  Widget _bufferingOverlay() {
    // Baomihua: centered ring + transfer rate under it.
    final rate = _formatTransferRate();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
          if (rate.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              rate,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? '播放出错',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => unawaited(_openCurrent(startAt: _position)),
                  child: const Text('重试', style: TextStyle(color: _accent)),
                ),
                TextButton(
                  onPressed: _handleBack,
                  child: const Text(
                    '返回',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toastOverlay() {
    return Center(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _toast == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              _toast ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _autoNextOverlay() {
    final next = _nextEpisode;
    if (next == null) return const SizedBox.shrink();
    return Positioned(
      right: 28,
      bottom: 110,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_autoNextSeconds}s 后播放下一集',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                next.displayLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: _cancelAutoNext,
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: () => unawaited(_playAdjacentEpisode(1)),
                    child: const Text('立即播放'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlsOverlay(BuildContext context) {
    if (PlatformCapabilities.isDesktop) {
      return _baomihuaChrome(context);
    }
    return _mobileChrome(context);
  }

  /// NetEase Baomihua desktop chrome clone: no back button, centered title,
  /// top-right rate + pin, bottom progress + vol/speed/quality + play + tools.
  Widget _baomihuaChrome(BuildContext context) {
    final rateLabel = _formatTransferRate();
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.72),
              ],
              stops: const [0, 0.22, 0.68, 1],
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: WindowChromeMetrics.macOSTitlebarHeight),
              // Top: [drag]  Title  rate  pin
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 120), // balance traffic lights / pin
                    Expanded(
                      child: Text(
                        _title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _chromeFg,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (rateLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          rateLabel,
                          style: const TextStyle(
                            color: _chromeDim,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: _alwaysOnTop ? '取消置顶' : '窗口置顶',
                      onPressed: () => unawaited(_toggleAlwaysOnTop()),
                      icon: Icon(
                        _alwaysOnTop
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        color: _alwaysOnTop ? Colors.white : _chromeDim,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _baomihuaBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _baomihuaBottomBar(BuildContext context) {
    final total = _duration.inMilliseconds;
    final current = _position.inMilliseconds.clamp(0, total == 0 ? 1 : total);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress row: time — slider — time
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: _chromeDim, fontSize: 12),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: total == 0 ? 0 : current.toDouble(),
                    max: total == 0 ? 1 : total.toDouble(),
                    onChangeStart: (_) {
                      _dragging = true;
                      _cancelAutoNext();
                      _hideTimer?.cancel();
                    },
                    onChanged: (value) {
                      setState(
                        () =>
                            _position = Duration(milliseconds: value.round()),
                      );
                    },
                    onChangeEnd: (value) async {
                      _dragging = false;
                      await _playback.seek(
                        Duration(milliseconds: value.round()),
                      );
                      _scheduleHideControls();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  _formatDuration(_duration),
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _chromeDim, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Controls: vol | 1.0x | 原画 |     ▶     | fullscreen audio sub
          Row(
            children: [
              IconButton(
                tooltip: _muted ? '取消静音' : '静音',
                onPressed: () => unawaited(_toggleMute()),
                icon: Icon(
                  _muted || _volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: _chromeDim,
                  size: 20,
                ),
              ),
              SizedBox(
                width: 88,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 8,
                    ),
                    activeTrackColor: Colors.white70,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _volume,
                    max: 100,
                    onChanged: _setVolume,
                  ),
                ),
              ),
              Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => _showSpeedControl(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: _chromeFg,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _formatRate(_rate),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showToast('当前为原画'),
                style: TextButton.styleFrom(
                  foregroundColor: _chromeDim,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('原画', style: TextStyle(fontSize: 13)),
              ),
              const Spacer(),
              IconButton(
                key: const Key('player_play_pause'),
                tooltip: _playing ? '暂停' : '播放',
                onPressed: _togglePlay,
                icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const Spacer(),
              if (_hasPrevEpisode)
                IconButton(
                  key: const Key('player_prev_episode'),
                  tooltip: '上一集 (P)',
                  icon: const Icon(Icons.skip_previous_rounded, size: 22),
                  color: _chromeDim,
                  onPressed: () => unawaited(_playAdjacentEpisode(-1)),
                ),
              if (_hasNextEpisode)
                IconButton(
                  key: const Key('player_next_episode'),
                  tooltip: '下一集 (N)',
                  icon: const Icon(Icons.skip_next_rounded, size: 22),
                  color: _chromeDim,
                  onPressed: () => unawaited(_playAdjacentEpisode(1)),
                ),
              IconButton(
                tooltip: '全屏 (F)',
                onPressed: () => unawaited(DesktopWindow.toggleFullScreen()),
                icon: const Icon(
                  Icons.fullscreen_rounded,
                  color: _chromeDim,
                  size: 22,
                ),
              ),
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: '音轨',
                  onPressed: () => _showAudioTracks(ctx),
                  icon: const Icon(
                    Icons.graphic_eq_rounded,
                    color: _chromeDim,
                    size: 20,
                  ),
                ),
              ),
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: '字幕',
                  onPressed: () => _showSubtitleTracks(ctx),
                  icon: const Icon(
                    Icons.subtitles_outlined,
                    color: _chromeDim,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileChrome(BuildContext context) {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0, 0.25, 0.65, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _mobileTopBar(context),
                const Spacer(),
                _mobileBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            key: const Key('player_back_button'),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            tooltip: '返回',
            onPressed: _handleBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_hasPrevEpisode)
            IconButton(
              key: const Key('player_prev_episode'),
              tooltip: '上一集',
              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
              onPressed: () => unawaited(_playAdjacentEpisode(-1)),
            ),
          if (_hasNextEpisode)
            IconButton(
              key: const Key('player_next_episode'),
              tooltip: '下一集',
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
              onPressed: () => unawaited(_playAdjacentEpisode(1)),
            ),
        ],
      ),
    );
  }

  Widget _mobileBottomBar(BuildContext context) {
    final total = _duration.inMilliseconds;
    final current = _position.inMilliseconds.clamp(0, total == 0 ? 1 : total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: total == 0 ? 0 : current.toDouble(),
                  max: total == 0 ? 1 : total.toDouble(),
                  onChangeStart: (_) {
                    _dragging = true;
                    _hideTimer?.cancel();
                  },
                  onChanged: (v) => setState(
                    () => _position = Duration(milliseconds: v.round()),
                  ),
                  onChangeEnd: (v) async {
                    _dragging = false;
                    await _playback.seek(Duration(milliseconds: v.round()));
                    _scheduleHideControls();
                  },
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => unawaited(_toggleMute()),
                      icon: Icon(
                        _muted || _volume == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white70,
                      ),
                    ),
                    Builder(
                      builder: (ctx) => TextButton(
                        onPressed: () => _showSpeedControl(ctx),
                        child: Text(
                          _formatRate(_rate),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                onPressed: _togglePlay,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(
                          Icons.graphic_eq_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => _showAudioTracks(ctx),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(
                          Icons.subtitles_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => _showSubtitleTracks(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Desktop popovers / mobile sheets ----------------------------------

  RelativeRect _menuRect(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) {
      return RelativeRect.fromLTRB(
        24,
        MediaQuery.sizeOf(buttonContext).height - 320,
        24,
        24,
      );
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromRect(
      Rect.fromLTWH(origin.dx, origin.dy, box.size.width, box.size.height),
      Offset.zero & overlay.size,
    );
  }

  Future<void> _showSpeedControl(BuildContext buttonContext) async {
    _hideTimer?.cancel();
    if (PlatformCapabilities.isDesktop) {
      await _showDesktopSpeedPopover(buttonContext);
    } else {
      await _showMobileSpeedSheet();
    }
    _scheduleHideControls();
  }

  Future<void> _showDesktopSpeedPopover(BuildContext buttonContext) async {
    setState(() => _optionSheetVisible = true);
    final rate = ValueNotifier<double>(_rate);
    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (dialogContext) {
          final rect = _menuRect(buttonContext);
          final size = MediaQuery.sizeOf(dialogContext);
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              Positioned(
                left: rect.left.clamp(12.0, size.width - 300),
                bottom: size.height - rect.top + 8,
                child: Material(
                  color: const Color(0xFF1E1F28),
                  elevation: 12,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: ValueListenableBuilder<double>(
                        valueListenable: rate,
                        builder: (context, value, _) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '播放速度',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatRate(value),
                                    style: const TextStyle(
                                      color: _accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: '减速',
                                    onPressed: () {
                                      final next = (value - _rateStep).clamp(
                                        _minRate,
                                        _maxRate,
                                      );
                                      rate.value = next;
                                      unawaited(_setRate(next));
                                    },
                                    icon: const Icon(
                                      Icons.remove_rounded,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                              enabledThumbRadius: 6,
                                            ),
                                        activeTrackColor: _accent,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                      ),
                                      child: Slider(
                                        value: value.clamp(_minRate, _maxRate),
                                        min: _minRate,
                                        max: _maxRate,
                                        // Continuous free adjustment (VLC/nPlayer).
                                        onChanged: (v) {
                                          rate.value = v;
                                        },
                                        onChangeEnd: (v) {
                                          unawaited(_setRate(v));
                                        },
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '加速',
                                    onPressed: () {
                                      final next = (value + _rateStep).clamp(
                                        _minRate,
                                        _maxRate,
                                      );
                                      rate.value = next;
                                      unawaited(_setRate(next));
                                    },
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final preset in _speedPresets)
                                    ChoiceChip(
                                      label: Text(_formatRate(preset)),
                                      selected: (value - preset).abs() < 0.01,
                                      onSelected: (_) {
                                        rate.value = preset;
                                        unawaited(_setRate(preset));
                                      },
                                      selectedColor: _accent.withValues(
                                        alpha: 0.35,
                                      ),
                                      labelStyle: TextStyle(
                                        color:
                                            (value - preset).abs() < 0.01
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 12,
                                      ),
                                      backgroundColor: Colors.white10,
                                      side: BorderSide.none,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    rate.value = 1.0;
                                    unawaited(_setRate(1.0));
                                  },
                                  child: const Text(
                                    '重置 1x',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      rate.dispose();
      if (mounted) setState(() => _optionSheetVisible = false);
    }
  }

  Future<void> _showMobileSpeedSheet() async {
    setState(() => _optionSheetVisible = true);
    final rate = ValueNotifier<double>(_rate);
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1B23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: ValueListenableBuilder<double>(
                valueListenable: rate,
                builder: (context, value, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '播放速度  ${_formatRate(value)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: value.clamp(_minRate, _maxRate),
                        min: _minRate,
                        max: _maxRate,
                        onChanged: (v) => rate.value = v,
                        onChangeEnd: (v) => unawaited(_setRate(v)),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final preset in _speedPresets)
                            ActionChip(
                              label: Text(_formatRate(preset)),
                              onPressed: () {
                                rate.value = preset;
                                unawaited(_setRate(preset));
                              },
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      rate.dispose();
      if (mounted) setState(() => _optionSheetVisible = false);
    }
  }

  Future<void> _showAudioTracks(BuildContext buttonContext) async {
    _hideTimer?.cancel();
    final tracks = _playback.audioTracks;
    final current = _playback.currentAudioTrack;
    if (PlatformCapabilities.isDesktop) {
      await _showDesktopTrackMenu(
        buttonContext: buttonContext,
        title: '音轨',
        entries: tracks.isEmpty
            ? const [('__empty__', '未检测到可切换的音轨')]
            : [
                for (final track in tracks)
                  (track.id, _audioTrackLabel(track)),
              ],
        selectedId: current.id,
        onSelected: (id) {
          final match = tracks.where((t) => t.id == id);
          if (match.isNotEmpty) unawaited(_playback.setAudioTrack(match.first));
        },
      );
    } else {
      setState(() => _optionSheetVisible = true);
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1B23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _optionSheet(
          title: '音轨',
          children: tracks.isEmpty
              ? [_emptyTracksHint('未检测到可切换的音轨')]
              : tracks
                    .map((track) {
                      return _optionTile(
                        label: _audioTrackLabel(track),
                        selected: track.id == current.id,
                        onTap: () {
                          unawaited(_playback.setAudioTrack(track));
                          Navigator.of(context).pop();
                        },
                      );
                    })
                    .toList(growable: false),
        ),
      );
      if (mounted) setState(() => _optionSheetVisible = false);
    }
    _scheduleHideControls();
  }

  Future<void> _showSubtitleTracks(BuildContext buttonContext) async {
    _hideTimer?.cancel();
    final embedded = _playback.subtitleTracks;
    final current = _playback.currentSubtitleTrack;

    final entries = <(String, String)>[];
    if (embedded.isEmpty && _externalSubs.isEmpty) {
      entries.add((
        '__empty__',
        _externalSubsLoaded ? '未检测到字幕（内嵌或同目录外挂）' : '正在扫描字幕…',
      ));
    } else {
      for (final track in embedded) {
        entries.add((track.id, _subtitleTrackLabel(track)));
      }
      // Dedupe external paths (same file can be discovered twice).
      final seen = <String>{};
      for (final sub in _externalSubs) {
        if (!seen.add(sub.uri)) continue;
        entries.add((sub.uri, sub.label));
      }
    }

    if (PlatformCapabilities.isDesktop) {
      await _showDesktopTrackMenu(
        buttonContext: buttonContext,
        title: '字幕',
        entries: entries,
        selectedId: current.id,
        onSelected: (id) {
          if (id == '__empty__') return;
          final embeddedMatch = embedded.where((t) => t.id == id);
          if (embeddedMatch.isNotEmpty) {
            unawaited(_playback.setSubtitleTrack(embeddedMatch.first));
            return;
          }
          final external = _externalSubs.where((s) => s.uri == id);
          if (external.isNotEmpty) {
            final sub = external.first;
            unawaited(
              _playback.setSubtitleTrack(
                PlaybackSubtitleTrack.uri(
                  sub.uri,
                  title: sub.label,
                  language: sub.languageHint,
                ),
              ),
            );
          }
        },
      );
    } else {
      setState(() => _optionSheetVisible = true);
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1B23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          final children = <Widget>[];
          if (embedded.isEmpty && _externalSubs.isEmpty) {
            children.add(
              _emptyTracksHint(
                _externalSubsLoaded ? '未检测到字幕（内嵌或同目录外挂）' : '正在扫描字幕…',
              ),
            );
          } else {
            for (final track in embedded) {
              children.add(
                _optionTile(
                  label: _subtitleTrackLabel(track),
                  selected: track.id == current.id,
                  onTap: () {
                    unawaited(_playback.setSubtitleTrack(track));
                    Navigator.of(context).pop();
                  },
                ),
              );
            }
            final seen = <String>{};
            for (final sub in _externalSubs) {
              if (!seen.add(sub.uri)) continue;
              final selected = current.uri && current.id == sub.uri;
              children.add(
                _optionTile(
                  label: sub.label,
                  selected: selected,
                  onTap: () {
                    unawaited(
                      _playback.setSubtitleTrack(
                        PlaybackSubtitleTrack.uri(
                          sub.uri,
                          title: sub.label,
                          language: sub.languageHint,
                        ),
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              );
            }
          }
          return _optionSheet(title: '字幕', children: children);
        },
      );
      if (mounted) setState(() => _optionSheetVisible = false);
    }
    _scheduleHideControls();
  }

  Future<void> _showDesktopTrackMenu({
    required BuildContext buttonContext,
    required String title,
    required List<(String, String)> entries,
    required String selectedId,
    required void Function(String id) onSelected,
  }) async {
    setState(() => _optionSheetVisible = true);
    try {
      final selected = await showMenu<String>(
        context: buttonContext,
        position: _menuRect(buttonContext),
        color: const Color(0xFF1E1F28),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        items: [
          PopupMenuItem<String>(
            enabled: false,
            height: 36,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const PopupMenuDivider(height: 8),
          for (final entry in entries)
            if (entry.$1 == '__empty__')
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  entry.$2,
                  style: const TextStyle(color: Colors.white54),
                ),
              )
            else
              PopupMenuItem<String>(
                value: entry.$1,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.$2,
                        style: TextStyle(
                          color: entry.$1 == selectedId
                              ? const Color(0xFF66A3FF)
                              : Colors.white,
                          fontWeight: entry.$1 == selectedId
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (entry.$1 == selectedId)
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Color(0xFF66A3FF),
                      ),
                  ],
                ),
              ),
        ],
      );
      if (selected != null) onSelected(selected);
    } finally {
      if (mounted) setState(() => _optionSheetVisible = false);
    }
  }

  Widget _optionSheet({required String title, required List<Widget> children}) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(child: Column(children: children)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _optionTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF66A3FF) : Colors.white,
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: Color(0xFF66A3FF))
          : null,
      onTap: onTap,
    );
  }

  Widget _emptyTracksHint(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white54, fontSize: 14),
      ),
    );
  }

  String _audioTrackLabel(PlaybackAudioTrack track) {
    if (track.id == '-1' || track.id == 'no') return '关闭';
    if (track.id == 'auto') return '自动';
    final parts = <String>[
      if (track.title != null && track.title!.isNotEmpty) track.title!,
      if (track.language != null && track.language!.isNotEmpty)
        '(${track.language})',
    ];
    return parts.isEmpty ? '音轨 ${track.id}' : parts.join(' ');
  }

  String _subtitleTrackLabel(PlaybackSubtitleTrack track) {
    if (track.id == '-1' || track.id == 'no') return '关闭';
    if (track.id == 'auto') return '自动';
    final parts = <String>[
      if (track.title != null && track.title!.isNotEmpty) track.title!,
      if (track.language != null && track.language!.isNotEmpty)
        '(${track.language})',
    ];
    return parts.isEmpty ? '字幕 ${track.id}' : parts.join(' ');
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }
}
