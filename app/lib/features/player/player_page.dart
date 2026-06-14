import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/playback_progress.dart';
import '../../data/repositories/playback_progress_repository.dart';
import '../../providers/data_providers.dart';
import '../../services/playback/playback_service.dart';
import '../../services/playback/vlc_video_view.dart';
import '../../core/platform/window_channel.dart';

/// Arguments passed to [PlayerPage] via go_router's `extra`.
class PlayerArgs {
  const PlayerArgs({
    required this.uri,
    required this.title,
    this.mediaId,
    this.startAt,
    this.httpHeaders,
  });

  /// Local file path or http:// stream URL.
  final String uri;
  final String title;
  final String? mediaId;
  final Duration? startAt;

  /// Optional HTTP headers (e.g. WebDAV Basic auth) for the source.
  final Map<String, String>? httpHeaders;
}

/// Full-screen player backed by VLCKit with a custom Apple-style control
/// layer on macOS and libVLC on Windows: play/pause, seek bar, speed,
/// subtitle & audio track selection, skip gestures, and keyboard shortcuts.
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
  static const _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const _nativeTopControlsReserve = 82.0;
  static const _nativeBottomControlsReserve = 138.0;
  static const _nativeBottomSheetReserve = 430.0;

  /// NetEase player accent — blue progress bar and scrubber.
  static const _accent = Color(0xFF2F6BFF);

  late final PlaybackService _playback;
  final FocusNode _focusNode = FocusNode();

  PlaybackProgressRepository? _progressRepo;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<PlaybackVideoEvent>? _videoEventSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _lastPersistedPosition = Duration.zero;
  bool _completed = false;
  bool _playing = true;
  bool _controlsVisible = true;
  bool _optionSheetVisible = false;
  bool _dragging = false;
  double _volume = 100;
  double _rate = 1.0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _playback = PlaybackService();
    _position = widget.args.startAt ?? Duration.zero;
    _lastPersistedPosition = _position;

    if (widget.args.mediaId != null) {
      _progressRepo = ref.read(playbackProgressRepositoryProvider);
    }
    _bindStreams();
    _videoEventSub = _playback.videoEvents.listen(_handleNativeVideoEvent);

    unawaited(
      _playback.open(
        widget.args.uri,
        startAt: widget.args.startAt,
        httpHeaders: widget.args.httpHeaders,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    _volumeSub?.cancel();
    _videoEventSub?.cancel();
    _focusNode.dispose();
    _playback.dispose();
    super.dispose();
  }

  void _bindStreams() {
    _positionSub = _playback.player.stream.position.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
      if ((position - _lastPersistedPosition).abs() >= _persistInterval) {
        unawaited(_persistProgress());
      }
    });
    _durationSub = _playback.player.stream.duration.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _playingSub = _playback.player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _playing = playing);
    });
    _volumeSub = _playback.player.stream.volume.listen((volume) {
      if (!mounted) return;
      setState(() => _volume = volume);
    });
    _completedSub = _playback.player.stream.completed.listen((completed) {
      _completed = completed;
      if (completed) {
        unawaited(_persistProgress(force: true));
      }
    });
  }

  void _handleNativeVideoEvent(PlaybackVideoEvent event) {
    if (!mounted) return;
    switch (event) {
      case PlaybackVideoEvent.tap:
        _toggleControls();
      case PlaybackVideoEvent.doubleTap:
        WindowChannel.toggleFullScreen();
    }
  }

  Future<void> _persistProgress({bool force = false}) async {
    final mediaId = widget.args.mediaId;
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
        if (mounted) _invalidateProgress();
      }
      return;
    }

    _lastPersistedPosition = snapshot.position;
    await repo.save(snapshot);
    if (mounted) _invalidateProgress();
  }

  void _invalidateProgress() {
    final mediaId = widget.args.mediaId;
    if (mediaId == null) return;
    ref.invalidate(playbackProgressByMediaIdProvider(mediaId));
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(recentlyWatchedMediaProvider);
  }

  Future<void> _handleBack() async {
    unawaited(_persistProgress(force: true));
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.pop();
    }
  }

  // --- Control interactions ----------------------------------------------

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_controlsHideDelay, () {
      if (mounted && _playing && !_dragging) {
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

  Future<void> _togglePlay() async {
    await _playback.playOrPause();
    _showControls();
  }

  Future<void> _skip(Duration delta) async {
    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
              ? _duration
              : target);
    await _playback.seek(clamped);
    setState(() => _position = clamped);
    _showControls();
  }

  Future<void> _setRate(double rate) async {
    await _playback.setRate(rate);
    setState(() => _rate = rate);
  }

  Future<void> _setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 100.0);
    await _playback.setVolume(clamped);
    setState(() => _volume = clamped);
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
    if (key == LogicalKeyboardKey.escape) {
      unawaited(WindowChannel.toggleFullScreen());
      unawaited(_handleBack());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: MouseRegion(
          onHover: (_) => _showControls(),
          child: Stack(
            children: [
              Positioned.fill(
                child: VlcVideoView(
                  service: _playback,
                  nativeOverlayInsets: _nativeOverlayInsets,
                ),
              ),
              // Tap zones: center toggles fullscreen/controls, sides double-tap to skip.
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
                        key: routeIsCurrent
                            ? const Key('player_center_gesture')
                            : null,
                        behavior: HitTestBehavior.translucent,
                        onTap: _toggleControls,
                        onDoubleTap: () {
                          WindowChannel.toggleFullScreen();
                        },
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
              _controlsOverlay(context, routeIsCurrent: routeIsCurrent),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets get _nativeOverlayInsets {
    final top = _controlsVisible ? _nativeTopControlsReserve : 0.0;
    final bottom = _optionSheetVisible
        ? _nativeBottomSheetReserve
        : (_controlsVisible ? _nativeBottomControlsReserve : 0.0);
    return EdgeInsets.only(top: top, bottom: bottom);
  }

  Widget _controlsOverlay(
    BuildContext context, {
    required bool routeIsCurrent,
  }) {
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
                _topBar(context, routeIsCurrent: routeIsCurrent),
                const Spacer(),
                _bottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, {required bool routeIsCurrent}) {
    final platform = Theme.of(context).platform;
    final leftPadding = platform == TargetPlatform.macOS
        ? WindowChromeMetrics.macOSTrafficLightReservedWidth
        : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(leftPadding, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            key: routeIsCurrent ? const Key('player_back_button') : null,
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
              widget.args.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerCluster() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(
            Icons.replay_10_rounded,
            color: Colors.white,
            size: 26,
          ),
          tooltip: '后退 10 秒',
          onPressed: () => _skip(-_skipStep),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(
            _playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            color: Colors.white,
            size: 44,
          ),
          tooltip: _playing ? '暂停' : '播放',
          onPressed: _togglePlay,
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(
            Icons.forward_10_rounded,
            color: Colors.white,
            size: 26,
          ),
          tooltip: '前进 10 秒',
          onPressed: () => _skip(_skipStep),
        ),
      ],
    );
  }

  Widget _bottomBar(BuildContext context) {
    final total = _duration.inMilliseconds;
    final current = _position.inMilliseconds.clamp(0, total == 0 ? 1 : total);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: time — blue progress — time (NetEase Mac player).
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: _accent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: _accent,
                    overlayColor: _accent.withValues(alpha: 0.24),
                  ),
                  child: Slider(
                    value: total == 0 ? 0 : current.toDouble(),
                    max: total == 0 ? 1 : total.toDouble(),
                    onChangeStart: (_) {
                      _dragging = true;
                      _hideTimer?.cancel();
                    },
                    onChanged: (value) {
                      setState(
                        () => _position = Duration(milliseconds: value.round()),
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
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          // Row 2: volume + speed | play cluster | audio + subtitles.
          Row(
            children: [
              Expanded(
                child: Row(children: [_volumeControl(), _speedButton()]),
              ),
              _centerCluster(),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _trackButton(
                      icon: Icons.graphic_eq_rounded,
                      tooltip: '音轨',
                      onTap: _showAudioTrackSheet,
                    ),
                    _trackButton(
                      icon: Icons.subtitles_rounded,
                      tooltip: '字幕',
                      onTap: _showSubtitleTrackSheet,
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

  Widget _volumeControl() {
    return SizedBox(
      width: 160,
      child: Row(
        children: [
          Icon(
            _volume == 0
                ? Icons.volume_off_rounded
                : (_volume < 50
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded),
            color: Colors.white70,
            size: 20,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: _accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(value: _volume, max: 100, onChanged: _setVolume),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedButton() {
    return TextButton(
      onPressed: _showSpeedSheet,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(
        '${_rate.toString().replaceAll(RegExp(r'\.0$'), '')}x',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _trackButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }

  // --- Bottom sheets ------------------------------------------------------

  void _markOptionSheetOpen() {
    _hideTimer?.cancel();
    setState(() {
      _controlsVisible = true;
      _optionSheetVisible = true;
    });
  }

  void _markOptionSheetClosed() {
    if (!mounted) return;
    setState(() => _optionSheetVisible = false);
    _scheduleHideControls();
  }

  void _showSpeedSheet() {
    _markOptionSheetOpen();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1B23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _optionSheet(
        title: '播放速度',
        children: _speedOptions
            .map((rate) {
              final label =
                  '${rate.toString().replaceAll(RegExp(r'\.0$'), '')}x';
              return _optionTile(
                label: rate == 1.0 ? '正常 (1x)' : label,
                selected: _rate == rate,
                onTap: () {
                  _setRate(rate);
                  Navigator.of(context).pop();
                },
              );
            })
            .toList(growable: false),
      ),
    ).whenComplete(_markOptionSheetClosed);
  }

  void _showAudioTrackSheet() {
    _markOptionSheetOpen();
    final tracks = _playback.audioTracks;
    final current = _playback.currentAudioTrack;
    showModalBottomSheet<void>(
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
                        _playback.setAudioTrack(track);
                        Navigator.of(context).pop();
                      },
                    );
                  })
                  .toList(growable: false),
      ),
    ).whenComplete(_markOptionSheetClosed);
  }

  void _showSubtitleTrackSheet() {
    _markOptionSheetOpen();
    final tracks = _playback.subtitleTracks;
    final current = _playback.currentSubtitleTrack;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1B23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _optionSheet(
        title: '字幕',
        children: tracks.isEmpty
            ? [_emptyTracksHint('未检测到字幕')]
            : tracks
                  .map((track) {
                    return _optionTile(
                      label: _subtitleTrackLabel(track),
                      selected: track.id == current.id,
                      onTap: () {
                        _playback.setSubtitleTrack(track);
                        Navigator.of(context).pop();
                      },
                    );
                  })
                  .toList(growable: false),
      ),
    ).whenComplete(_markOptionSheetClosed);
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
    if (track.id == '-1') return '关闭';
    final parts = <String>[
      if (track.title != null && track.title!.isNotEmpty) track.title!,
      if (track.language != null && track.language!.isNotEmpty)
        '(${track.language})',
    ];
    return parts.isEmpty ? '音轨 ${track.id}' : parts.join(' ');
  }

  String _subtitleTrackLabel(PlaybackSubtitleTrack track) {
    if (track.id == '-1') return '关闭';
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
