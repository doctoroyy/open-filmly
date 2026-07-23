import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../../core/platform/desktop_window.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/platform/window_channel.dart';
import '../../data/models/episode.dart';
import '../../data/models/playback_progress.dart';
import '../../data/repositories/playback_progress_repository.dart';
import '../../providers/data_providers.dart';
import '../../providers/intelligence_providers.dart';
import '../../services/library/media_library_entry_factory.dart';
import '../../providers/smb_providers.dart';
import '../../services/metadata/tmdb_metadata_service.dart';
import '../../services/playback/external_subtitle_finder.dart';
import '../../services/playback/playback_service.dart';
import '../../services/playback/playback_source_resolver.dart';
import '../../services/playback/subtitle_preference.dart';
import '../../services/playback/vlc_video_view.dart';
import '../../services/intelligence/media_identity_service.dart';
import '../../services/intelligence/intelligence_storage.dart';
import '../../data/intelligence/watch_event_repository.dart';
import '../../features/intelligence/companion_sheet.dart';

/// Host handle so the window chrome can stop VLC **before** the NSWindow is
/// torn down (otherwise audio keeps playing in the background).
class PlayerHostHandle {
  Future<void> Function()? stopPlayback;
}

/// Arguments passed to [PlayerPage] via go_router's `extra` or a player window.
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

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'title': title,
    'mediaId': mediaId,
    'startAtMs': startAt?.inMilliseconds,
    'httpHeaders': httpHeaders,
    'subtitles': [
      for (final s in subtitles)
        {'uri': s.uri, 'title': s.title, 'language': s.language},
    ],
    'showId': showId,
    'showTitle': showTitle,
  };

  factory PlayerArgs.fromJson(Map<String, dynamic> json) {
    final startMs = json['startAtMs'];
    final headers = json['httpHeaders'];
    final subs = json['subtitles'];
    return PlayerArgs(
      uri: json['uri']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      mediaId: json['mediaId']?.toString(),
      startAt: startMs is int ? Duration(milliseconds: startMs) : null,
      httpHeaders: headers is Map
          ? headers.map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
      subtitles: subs is List
          ? [
              for (final item in subs)
                if (item is Map)
                  PlaybackSubtitleSource(
                    uri: item['uri']?.toString() ?? '',
                    title: item['title']?.toString() ?? '',
                    language: item['language']?.toString(),
                  ),
            ]
          : const [],
      showId: json['showId']?.toString(),
      showTitle: json['showTitle']?.toString(),
    );
  }
}

/// Full-screen player backed by native VLCKit with a NetEase-style control layer.
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, required this.args, this.onClose, this.host});

  final PlayerArgs args;

  /// When set (standalone player window), invoked instead of Navigator.pop.
  final VoidCallback? onClose;

  /// Optional host bridge so the window chrome can stop audio before closing.
  final PlayerHostHandle? host;

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
  String? _memoryAssetId;
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
  bool _playing = false;
  bool? _lastMemoryPlaying;
  bool _buffering = true;
  bool _controlsVisible = true;
  bool _optionSheetVisible = false;
  bool _dragging = false;

  /// True until the first real frame/play event — keeps Baomihua-style spinner.
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
  Duration _speedSamplePosition = Duration.zero;
  Timer? _hideTimer;
  Timer? _toastTimer;
  Timer? _autoNextTimer;
  Timer? _speedSampleTimer;
  String? _toast;
  int _autoNextSeconds = 0;

  List<Episode> _episodes = const [];
  int _episodeIndex = -1;

  /// Baomihua-style right-side drawers (only one open at a time).
  bool _episodePanelOpen = false;
  bool _audioPanelOpen = false;
  bool _subtitlePanelOpen = false;

  /// Selected season in the panel (not necessarily the currently playing one).
  int _panelSeason = 1;

  /// Which 10-episode page is selected inside the panel (0-based).
  int _episodePageIndex = 0;

  /// Cache of TMDB episode metadata: "season:episode" → details.
  final Map<String, TmdbEpisodeDetails> _tmdbEpisodeMeta = {};
  bool _loadingSeasonMeta = false;
  List<ExternalSubtitleFile> _externalSubs = const [];
  bool _externalSubsLoaded = false;
  String? _autoSubtitleKey;
  bool _applyingSubtitlePreference = false;
  bool _subtitlePreferencePending = false;

  bool get _anySidePanelOpen =>
      _episodePanelOpen || _audioPanelOpen || _subtitlePanelOpen;

  @override
  void initState() {
    super.initState();
    _playback = PlaybackService();
    widget.host?.stopPlayback = _stopPlaybackForHost;
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

  Future<void> _stopPlaybackForHost() async {
    try {
      await _persistProgress(force: true);
    } catch (_) {}
    try {
      await _playback.stop();
    } catch (_) {}
    try {
      _playback.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (widget.host?.stopPlayback == _stopPlaybackForHost) {
      widget.host?.stopPlayback = null;
    }
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
    // May already have been disposed by host close path.
    try {
      _playback.dispose();
    } catch (_) {}
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

  bool get _isNetworkUri {
    final u = _uri;
    return u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('smb://') ||
        u.startsWith('webdav://') ||
        u.startsWith('webdavs://');
  }

  void _sampleTransferRate() {
    if (!mounted) return;
    final now = DateTime.now();
    final prevAt = _speedSampleAt;
    final prevBuf = _speedSampleBuffer;
    final prevPos = _speedSamplePosition;
    _speedSampleAt = now;
    _speedSampleBuffer = _buffer;
    _speedSamplePosition = _position;
    if (prevAt == null) return;
    final dt = now.difference(prevAt).inMilliseconds;
    if (dt <= 0) return;

    // Prefer buffer-ahead growth (true download progress while opening /
    // seeking). Fall back to played-duration growth while the stream is
    // steady so the top-right rate stays non-zero like Baomihua.
    final dBufMs = (_buffer - prevBuf).inMilliseconds;
    final dPosMs = (_position - prevPos).inMilliseconds;
    final advanceMs = dBufMs > 0
        ? dBufMs
        : ((_playing && !_buffering && dPosMs > 0) ? dPosMs : 0);

    if (advanceMs <= 0) {
      // Keep last sample briefly while loading so UI doesn't flash "0 KB/s"
      // between packets; only zero after a longer stall.
      if ((_buffering || _opening) &&
          now.difference(prevAt).inMilliseconds > 1500 &&
          _transferBytesPerSec != 0) {
        setState(() => _transferBytesPerSec = 0);
      }
      return;
    }

    // ~8 Mbps nominal media bitrate when we only know duration growth.
    const assumedBitsPerSecond = 8 * 1000 * 1000;
    final bytes = (advanceMs / 1000.0) * (assumedBitsPerSecond / 8.0);
    final bps = bytes / (dt / 1000.0);
    // Exponential smooth so the label doesn't jump every sample.
    final smoothed = _transferBytesPerSec <= 0
        ? bps
        : (_transferBytesPerSec * 0.55 + bps * 0.45);
    setState(() => _transferBytesPerSec = smoothed.clamp(0, 200 * 1024 * 1024));
  }

  /// Transfer rate label (Baomihua top-right + loading spinner).
  /// Always visible while opening/buffering; while playing show whenever we
  /// have a sample (or "0 KB/s" for network sources).
  String _formatTransferRate() {
    final bps = _transferBytesPerSec;
    if (bps >= 1024 * 1024) {
      return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bps >= 1024) {
      return '${(bps / 1024).toStringAsFixed(0)} KB/s';
    }
    if (bps > 0) {
      // Sub-KB rates still render as KB so the unit stays stable.
      return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    }
    if (_buffering || _opening || _isNetworkUri || _controlsVisible) {
      return '0 KB/s';
    }
    return '';
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
      _playing = false;
      _error = null;
      _completed = false;
      _externalSubs = const [];
      _externalSubsLoaded = false;
      _autoSubtitleKey = null;
      _cancelAutoNext();
    });
    try {
      await _resolveMemoryAsset();
      await _playback.open(_uri, startAt: startAt, httpHeaders: _httpHeaders);
      if (!mounted) return;
      // Keep [_opening] true until playback actually starts (or buffering
      // settles with a known duration). Clearing it here made the spinner
      // vanish while the window was still black.
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

  void _markMediaReady() {
    if (!_opening || !mounted) return;
    setState(() => _opening = false);
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
      final season = idx >= 0
          ? episodes[idx].seasonNumber
          : (episodes.isNotEmpty ? episodes.first.seasonNumber : 1);
      setState(() {
        _episodes = episodes;
        _episodeIndex = idx;
        _panelSeason = season;
        _syncPanelToPlayingEpisode();
      });
      // Prefetch TMDB Chinese titles for the current season.
      unawaited(_ensureSeasonMeta(season));
    } catch (_) {
      // Playlist is best-effort.
    }
  }

  Future<void> _ensureSeasonMeta(int seasonNumber) async {
    final showId = widget.args.showId;
    if (showId == null || showId.isEmpty) return;
    // Skip if we already have any episode meta for this season.
    final hasAny = _tmdbEpisodeMeta.keys.any(
      (k) => k.startsWith('$seasonNumber:'),
    );
    if (hasAny) return;

    final show = await ref.read(mediaByIdProvider(showId).future);
    final tmdbId = show?.tmdbId;
    if (tmdbId == null) return;
    final config = await ref.read(configProvider.future);
    if (config.tmdbApiKey.isEmpty) return;

    if (mounted) setState(() => _loadingSeasonMeta = true);
    try {
      final map = await ref
          .read(tmdbMetadataProvider)
          .fetchSeasonEpisodes(
            tvId: tmdbId,
            seasonNumber: seasonNumber,
            apiKey: config.tmdbApiKey,
          );
      if (!mounted) return;
      setState(() {
        for (final entry in map.entries) {
          _tmdbEpisodeMeta['$seasonNumber:${entry.key}'] = entry.value;
        }
        _loadingSeasonMeta = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSeasonMeta = false);
    }
  }

  TmdbEpisodeDetails? _metaFor(Episode ep) =>
      _tmdbEpisodeMeta['${ep.seasonNumber}:${ep.episodeNumber}'];

  String _displayEpisodeTitle(Episode ep) {
    final meta = _metaFor(ep);
    if (meta != null && meta.name.isNotEmpty) return meta.name;
    // Strip release-group noise from raw file basenames.
    final raw = ep.title.trim();
    if (raw.isEmpty) return '第${ep.episodeNumber}集';
    if (RegExp(
      r'(rovers|amzn|ntb|web-?dl|bluray|x264|x265|1080p|720p)',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return '第${ep.episodeNumber}集';
    }
    return raw;
  }

  String _displayEpisodeOverview(Episode ep) {
    final meta = _metaFor(ep);
    if (meta != null && meta.overview.isNotEmpty) return meta.overview;
    return '';
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
      final generated = await _findGeneratedSubtitle();
      if (generated != null) found.add(generated);
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

  Future<ExternalSubtitleFile?> _findGeneratedSubtitle() async {
    final localPath = _localPathForAiSubtitle(_uri);
    if (localPath == null) return null;
    try {
      final identity = await MediaIdentityService.fromFile(path: localPath);
      final segments = await ref
          .read(transcriptServiceProvider)
          .getByAsset(identity.identityKey);
      if (segments.isEmpty) return null;
      final config = await ref.read(configProvider.future);
      final targetLanguage = config.aiTargetLanguage.trim();
      final translated =
          targetLanguage.isNotEmpty &&
          segments.any(
            (segment) => segment.translatedText?.trim().isNotEmpty == true,
          );
      final sourceLanguage = segments
          .map((segment) => segment.language.trim())
          .firstWhere(
            (language) => language.isNotEmpty,
            orElse: () => 'source',
          );
      final language = translated ? targetLanguage : sourceLanguage;
      final directory = config.aiIndexDirectory.trim().isEmpty
          ? Directory(
              '${(await defaultIntelligenceDirectory()).path}/subtitles',
            )
          : Directory(p.join(config.aiIndexDirectory.trim(), 'subtitles'));
      final artifact = await ref
          .read(subtitleGenerationServiceProvider)
          .writeSrt(
            assetId: identity.identityKey,
            directory: directory,
            language: language,
            translated: translated,
          );
      return ExternalSubtitleFile(
        path: artifact.file.path,
        label: translated
            ? 'AI 字幕 · $targetLanguage'
            : 'AI 转录 · $sourceLanguage',
        languageHint: language,
      );
    } catch (_) {
      // AI subtitles are an optional enhancement and must never block playback.
      return null;
    }
  }

  Future<void> _openCompanion() async {
    final localPath = _localPathForAiSubtitle(_uri);
    if (localPath == null) {
      _showToast('AI Companion 当前只支持本地媒体');
      return;
    }
    try {
      final identity = await MediaIdentityService.fromFile(path: localPath);
      var segments = await ref
          .read(transcriptServiceProvider)
          .getByAsset(identity.identityKey);
      // Prefer existing sidecar subtitles so Companion works without ASR.
      if (segments.isEmpty && _mediaId != null) {
        final media = await ref.read(mediaByIdProvider(_mediaId!).future);
        if (media != null) {
          await ref.read(libraryIntelligenceIndexerProvider).indexMedia(media);
          segments = await ref
              .read(transcriptServiceProvider)
              .getByAsset(identity.identityKey);
        }
      }
      if (segments.isEmpty) {
        _showToast('这部媒体还没有可用字幕。可先放同目录 .srt，或在 Media Intelligence 里建立索引');
        return;
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CompanionSheet(
          assetId: identity.identityKey,
          positionMs: _position.inMilliseconds,
          title: _title,
          onJumpTo: (positionMs) async {
            await _playback.seek(Duration(milliseconds: positionMs));
          },
        ),
      );
    } catch (error) {
      _showToast('无法打开 AI Companion：$error');
    }
  }

  String? _localPathForAiSubtitle(String uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed?.scheme == 'file') return parsed!.toFilePath();
    if (parsed?.hasScheme == true) return null;
    if (uri.trim().isEmpty) return null;
    return uri;
  }

  Future<void> _resolveMemoryAsset() async {
    final localPath = _localPathForAiSubtitle(_uri);
    if (localPath == null) {
      _memoryAssetId = _mediaId ?? _uri;
      return;
    }
    try {
      final identity = await MediaIdentityService.fromFile(path: localPath);
      _memoryAssetId = identity.identityKey;
    } catch (_) {
      _memoryAssetId = _mediaId ?? localPath;
    }
  }

  void _recordMemoryEvent(
    WatchEventKind kind, {
    Map<String, dynamic> payload = const {},
  }) {
    unawaited(_recordMemoryEventAsync(kind, payload: payload));
  }

  Future<void> _recordMemoryEventAsync(
    WatchEventKind kind, {
    required Map<String, dynamic> payload,
  }) async {
    final config = ref.read(configProvider).asData?.value;
    if (config?.aiMemoryEnabled == false) return;
    final assetId = _memoryAssetId ?? _mediaId ?? (_isNetworkUri ? null : _uri);
    if (assetId == null || assetId.isEmpty) return;
    try {
      await ref
          .read(personalMemoryServiceProvider)
          .record(
            assetId: assetId,
            kind: kind,
            positionMs: _position.inMilliseconds,
            durationMs: _duration.inMilliseconds > 0
                ? _duration.inMilliseconds
                : null,
            payload: payload,
          );
    } catch (_) {
      // Viewing memory is optional and must never affect playback.
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
      // Duration known + not buffering ⇒ treat as ready (local files often
      // skip the "playing" edge for a moment after open).
      if (duration > Duration.zero && !_buffering) _markMediaReady();
    });
    _bufferSub = _playback.player.stream.buffer.listen((buffer) {
      if (!mounted) return;
      setState(() => _buffer = buffer);
    });
    _playingSub = _playback.player.stream.playing.listen((playing) {
      if (!mounted) return;
      final previous = _lastMemoryPlaying;
      _lastMemoryPlaying = playing;
      if (previous == null && playing) {
        _recordMemoryEvent(WatchEventKind.play);
      } else if (previous != null && previous != playing) {
        _recordMemoryEvent(
          playing ? WatchEventKind.play : WatchEventKind.pause,
        );
      }
      setState(() => _playing = playing);
      if (playing) {
        _markMediaReady();
        _scheduleHideControls();
      }
    });
    _bufferingSub = _playback.player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      setState(() => _buffering = buffering);
      if (!buffering && (_playing || _duration > Duration.zero)) {
        _markMediaReady();
      }
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
        _recordMemoryEvent(WatchEventKind.completed);
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
    if (!snapshot.completed) _recordMemoryEvent(WatchEventKind.progress);
    if (mounted) _invalidateProgress(mediaId);
  }

  void _invalidateProgress(String mediaId) {
    ref.invalidate(playbackProgressByMediaIdProvider(mediaId));
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(recentlyWatchedMediaProvider);
  }

  Future<void> _handleBack() async {
    _cancelAutoNext();
    if (!_completed) _recordMemoryEvent(WatchEventKind.abandon);
    await _persistProgress(force: true);
    if (!mounted) return;
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    if (context.canPop()) {
      context.pop();
    }
  }

  // --- Control interactions ----------------------------------------------

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    if (_anySidePanelOpen || _optionSheetVisible) {
      // Keep chrome while a drawer / sheet is open.
      return;
    }
    _hideTimer = Timer(_controlsHideDelay, () {
      if (!mounted ||
          _dragging ||
          _error != null ||
          _anySidePanelOpen ||
          _optionSheetVisible ||
          _opening) {
        return;
      }
      // Don't require _playing — on mobile VLC may report paused while still
      // watching; chrome should still auto-dismiss.
      setState(() => _controlsVisible = false);
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
    _recordMemoryEvent(
      WatchEventKind.skip,
      payload: {'deltaMs': delta.inMilliseconds},
    );
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
    final targetIndex = _episodeIndex + delta;
    if (targetIndex < 0 || targetIndex >= _episodes.length) return;
    await _playEpisodeAt(targetIndex, toast: delta > 0 ? '下一集' : '上一集');
  }

  Future<void> _playEpisodeAt(int targetIndex, {String? toast}) async {
    _cancelAutoNext();
    if (targetIndex < 0 || targetIndex >= _episodes.length) return;

    final showId = widget.args.showId;
    if (showId == null) return;

    await _persistProgress(force: true);

    final episode = _episodes[targetIndex];
    try {
      setState(() {
        _opening = true;
        _buffering = true;
        _playing = false;
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
        _memoryAssetId = null;
        _lastMemoryPlaying = null;
        _title =
            '${widget.args.showTitle ?? show.title} - ${episode.displayLabel}';
        _episodeIndex = targetIndex;
        // Page tabs are per-season episode-number ranges (1-10 / 11-20…),
        // never the global playlist index.
        _syncPanelToPlayingEpisode();
        _position = Duration.zero;
        _duration = Duration.zero;
        _buffer = Duration.zero;
        _lastPersistedPosition = Duration.zero;
        _progressRepo = ref.read(playbackProgressRepositoryProvider);
      });
      await DesktopWindow.setTitle(_title);
      await _openCurrent();
      if (toast != null) _showToast(toast);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = '切换剧集失败：$e';
      });
    }
  }

  /// Align season tab + 1-10/11-20 page to the currently playing episode.
  /// Uses **episodeNumber** ranges (Baomihua), not the global list index.
  void _syncPanelToPlayingEpisode() {
    if (_episodeIndex < 0 || _episodeIndex >= _episodes.length) return;
    final current = _episodes[_episodeIndex];
    _panelSeason = current.seasonNumber;
    final epNo = current.episodeNumber;
    _episodePageIndex = epNo > 0 ? (epNo - 1) ~/ 10 : 0;
  }

  void _toggleEpisodePanel() {
    setState(() {
      final opening = !_episodePanelOpen;
      _episodePanelOpen = opening;
      if (opening) {
        _audioPanelOpen = false;
        _subtitlePanelOpen = false;
        _controlsVisible = true;
        _syncPanelToPlayingEpisode();
        _hideTimer?.cancel();
        unawaited(_ensureSeasonMeta(_panelSeason));
      } else {
        _scheduleHideControls();
      }
    });
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
      if (_anySidePanelOpen) {
        _closeAllSidePanels();
        return KeyEventResult.handled;
      }
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
                  // Always transparent on desktop: Flutter gesture layer owns
                  // taps. Toggling this with the drawer remounts AppKitView and
                  // feels like a 0.5–1s hitch.
                  platformViewHitTestable: !PlatformCapabilities.isDesktop,
                ),
              ),
              // Desktop (VLC / nPlayer): whole surface single-click toggles
              // chrome, double-click toggles fullscreen. Mobile keeps the
              // left/center/right seek + play zones.
              if (PlatformCapabilities.isDesktop)
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('player_desktop_gesture'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_anySidePanelOpen) {
                        _closeAllSidePanels();
                      } else {
                        _toggleControls();
                      }
                    },
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
              // Desktop drawers live inside baomihua chrome; mobile uses sheets.
              if (PlatformCapabilities.isDesktop) ...[
                if (_episodes.isNotEmpty) _episodeSidePanel(),
                _audioSidePanel(),
                _subtitleSidePanel(),
              ],
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
    // Baomihua: dim stage + centered ring + transfer rate (or 加载中).
    final rate = _formatTransferRate();
    final label = rate.isNotEmpty ? rate : '加载中…';
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: _opening ? 0.55 : 0.28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.2,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
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

  /// NetEase Baomihua desktop chrome: title lives **on the titlebar row**
  /// (same line as traffic lights), rate + pin on the right, no back button.
  Widget _baomihuaChrome(BuildContext context) {
    final rateLabel = _formatTransferRate();
    final titlebarH = WindowChromeMetrics.macOSTitlebarHeight;
    return Stack(
      children: [
        // Gradient only when chrome is visible.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
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
            ),
          ),
        ),
        // Titlebar row — always participates in hit-testing for drag / pin,
        // even when the rest of the chrome is auto-hidden (Baomihua keeps the
        // titlebar usable).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: titlebarH,
          child: DragToMoveArea(
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      // Traffic-light clearance (system draws buttons here).
                      SizedBox(
                        width:
                            WindowChromeMetrics.macOSTrafficLightReservedWidth,
                      ),
                      Expanded(
                        child: Text(
                          _title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _chromeFg,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      // Always show transfer rate next to the title when chrome
                      // is visible (Baomihua top-right). Empty string is rare.
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          rateLabel.isEmpty ? '0 KB/s' : rateLabel,
                          style: const TextStyle(
                            color: _chromeDim,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _alwaysOnTop ? '取消置顶' : '窗口置顶',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 28,
                        ),
                        onPressed: () => unawaited(_toggleAlwaysOnTop()),
                        icon: Icon(
                          _alwaysOnTop
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          color: _alwaysOnTop ? Colors.white : _chromeDim,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Bottom bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: _baomihuaBottomBar(context),
            ),
          ),
        ),
        // Episode drawer only on desktop chrome stack (audio/subs too).
        if (_episodes.isNotEmpty) _episodeSidePanel(),
        _audioSidePanel(),
        _subtitleSidePanel(),
      ],
    );
  }

  void _closeAllSidePanels() {
    if (!_anySidePanelOpen) return;
    setState(() {
      _episodePanelOpen = false;
      _audioPanelOpen = false;
      _subtitlePanelOpen = false;
    });
    _scheduleHideControls();
  }

  Future<void> _openAudioPanel() async {
    if (PlatformCapabilities.isDesktop) {
      setState(() {
        _audioPanelOpen = true;
        _subtitlePanelOpen = false;
        _episodePanelOpen = false;
        _controlsVisible = true;
        _hideTimer?.cancel();
      });
      return;
    }
    await _showMobileAudioSheet();
  }

  Future<void> _openSubtitlePanel() async {
    if (PlatformCapabilities.isDesktop) {
      setState(() {
        _subtitlePanelOpen = true;
        _audioPanelOpen = false;
        _episodePanelOpen = false;
        _controlsVisible = true;
        _hideTimer?.cancel();
      });
      return;
    }
    await _showMobileSubtitleSheet();
  }

  Future<void> _showMobileAudioSheet() async {
    _hideTimer?.cancel();
    setState(() {
      _controlsVisible = true;
      _optionSheetVisible = true;
    });
    final tracks = _playback.audioTracks;
    final current = _playback.currentAudioTrack;
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1B23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '音轨',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tracks.isEmpty)
                    const Text(
                      '未检测到可切换的音轨',
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final track in tracks)
                          ChoiceChip(
                            label: Text(
                              _audioTrackLabel(track),
                              style: TextStyle(
                                color: track.id == current.id
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            selected: track.id == current.id,
                            selectedColor: Colors.white,
                            backgroundColor: const Color(0xFF2A2B33),
                            onSelected: (_) {
                              unawaited(_playback.setAudioTrack(track));
                              Navigator.of(ctx).pop();
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _optionSheetVisible = false);
        _scheduleHideControls();
      }
    }
  }

  Future<void> _showMobileSubtitleSheet() async {
    _hideTimer?.cancel();
    setState(() {
      _controlsVisible = true;
      _optionSheetVisible = true;
    });
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1B23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final embedded = _playback.subtitleTracks
              .where((t) => t.id != '-1' && t.id.isNotEmpty)
              .toList(growable: false);
          final current = _playback.currentSubtitleTrack;
          final offSelected = current.id == '-1' || current.id.isEmpty;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '字幕',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _pickAndAddSubtitle();
                        },
                        child: const Text(
                          '+ 添加',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Horizontal chips — no long ActionSheet list.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              '关闭',
                              style: TextStyle(
                                color: offSelected
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            selected: offSelected,
                            selectedColor: Colors.white,
                            backgroundColor: const Color(0xFF2A2B33),
                            onSelected: (_) {
                              unawaited(
                                _playback.setSubtitleTrack(
                                  PlaybackSubtitleTrack.no(),
                                ),
                              );
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ),
                        for (final track in embedded)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                _subtitleTrackLabel(track),
                                style: TextStyle(
                                  color: track.id == current.id
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              selected: track.id == current.id,
                              selectedColor: Colors.white,
                              backgroundColor: const Color(0xFF2A2B33),
                              onSelected: (_) {
                                unawaited(_playback.setSubtitleTrack(track));
                                Navigator.of(ctx).pop();
                              },
                            ),
                          ),
                        for (final sub in _externalSubs)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                sub.label,
                                style: TextStyle(
                                  color: current.uri && current.id == sub.uri
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              selected: current.uri && current.id == sub.uri,
                              selectedColor: Colors.white,
                              backgroundColor: const Color(0xFF2A2B33),
                              onSelected: (_) {
                                unawaited(
                                  _playback.setSubtitleTrack(
                                    PlaybackSubtitleTrack.uri(
                                      sub.uri,
                                      title: sub.label,
                                      language: sub.languageHint,
                                    ),
                                  ),
                                );
                                Navigator.of(ctx).pop();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _optionSheetVisible = false);
        _scheduleHideControls();
      }
    }
  }

  Widget _episodeSidePanel() {
    final seasons = <int, List<Episode>>{};
    for (final ep in _episodes) {
      seasons.putIfAbsent(ep.seasonNumber, () => []).add(ep);
    }
    for (final list in seasons.values) {
      list.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    }
    final seasonNumbers = seasons.keys.toList()..sort();
    if (seasonNumbers.isEmpty) return const SizedBox.shrink();

    final panelSeason = seasonNumbers.contains(_panelSeason)
        ? _panelSeason
        : seasonNumbers.first;
    final seasonEps = seasons[panelSeason] ?? const <Episode>[];
    // Baomihua pages by episode number: 1-10 / 11-20 / 21-24 …
    final maxEpNo = seasonEps.isEmpty
        ? 0
        : seasonEps.map((e) => e.episodeNumber).reduce((a, b) => a > b ? a : b);
    final pageCount = maxEpNo <= 0 ? 1 : ((maxEpNo + 9) ~/ 10).clamp(1, 99);
    final page = _episodePageIndex.clamp(0, pageCount - 1);
    final pageStart = page * 10 + 1;
    final pageEnd = (page + 1) * 10;
    final pageEps = seasonEps
        .where(
          (e) => e.episodeNumber >= pageStart && e.episodeNumber <= pageEnd,
        )
        .toList(growable: false);

    // Drawer only — outside-tap closes via root desktop gesture layer.
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_episodePanelOpen,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          offset: _episodePanelOpen ? Offset.zero : const Offset(1, 0),
          child: Material(
            color: const Color(0xF0141418),
            elevation: 16,
            child: SizedBox(
              width: 360,
              child: SafeArea(
                left: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '第$panelSeason季（共${seasonEps.length}集）',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_loadingSeasonMeta)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white38,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Season tabs — all seasons of the show, not just current.
                    if (seasonNumbers.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final s in seasonNumbers)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(
                                      '第$s季',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: panelSeason == s
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                    selected: panelSeason == s,
                                    onSelected: (_) {
                                      setState(() {
                                        _panelSeason = s;
                                        // If still watching this season, keep
                                        // the page that contains the playing ep.
                                        if (_episodeIndex >= 0 &&
                                            _episodes[_episodeIndex]
                                                    .seasonNumber ==
                                                s) {
                                          _syncPanelToPlayingEpisode();
                                        } else {
                                          _episodePageIndex = 0;
                                        }
                                      });
                                      unawaited(_ensureSeasonMeta(s));
                                    },
                                    selectedColor: Colors.white24,
                                    backgroundColor: Colors.white10,
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    // Episode range pages by episodeNumber (not list index).
                    if (pageCount > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < pageCount; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(
                                      '${i * 10 + 1}-${((i + 1) * 10).clamp(1, maxEpNo)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: page == i
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                    selected: page == i,
                                    onSelected: (_) {
                                      setState(() => _episodePageIndex = i);
                                    },
                                    selectedColor: Colors.white24,
                                    backgroundColor: Colors.white10,
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: pageEps.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final ep = pageEps[i];
                          final globalIndex = _episodes.indexWhere(
                            (e) => e.id == ep.id,
                          );
                          final playing = globalIndex == _episodeIndex;
                          final title = _displayEpisodeTitle(ep);
                          final overview = _displayEpisodeOverview(ep);
                          final still = _metaFor(ep)?.stillUrl;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              unawaited(
                                _playEpisodeAt(
                                  globalIndex,
                                  toast: '第${ep.episodeNumber}集',
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: playing
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: playing
                                      ? Colors.white30
                                      : Colors.white10,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 100,
                                      height: 56,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (still != null && still.isNotEmpty)
                                            Image.network(
                                              still,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                    color: Colors.white10,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '${ep.episodeNumber}',
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                            )
                                          else
                                            Container(
                                              color: Colors.white10,
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${ep.episodeNumber}',
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          if (playing)
                                            Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Container(
                                                width: double.infinity,
                                                color: Colors.black54,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: const Text(
                                                  '正在播放',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${ep.episodeNumber}. $title',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: playing
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.92,
                                                  ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (overview.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            overview,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
              // Baomihua center: prev / play / next (episode for TV)
              if (_episodes.isNotEmpty)
                IconButton(
                  key: const Key('player_prev_episode'),
                  tooltip: '上一集 (P)',
                  onPressed: _hasPrevEpisode
                      ? () => unawaited(_playAdjacentEpisode(-1))
                      : null,
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: _hasPrevEpisode ? Colors.white : Colors.white24,
                    size: 26,
                  ),
                ),
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
              if (_episodes.isNotEmpty)
                IconButton(
                  key: const Key('player_next_episode'),
                  tooltip: '下一集 (N)',
                  onPressed: _hasNextEpisode
                      ? () => unawaited(_playAdjacentEpisode(1))
                      : null,
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: _hasNextEpisode ? Colors.white : Colors.white24,
                    size: 26,
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: '全屏 (F)',
                onPressed: () => unawaited(DesktopWindow.toggleFullScreen()),
                icon: const Icon(
                  Icons.fullscreen_rounded,
                  color: _chromeDim,
                  size: 22,
                ),
              ),
              IconButton(
                tooltip: '音轨',
                onPressed: _openAudioPanel,
                icon: Icon(
                  Icons.graphic_eq_rounded,
                  color: _audioPanelOpen ? Colors.white : _chromeDim,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'AI Companion',
                onPressed: () => unawaited(_openCompanion()),
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _chromeDim,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: '字幕',
                onPressed: _openSubtitlePanel,
                icon: Icon(
                  Icons.subtitles_outlined,
                  color: _subtitlePanelOpen ? Colors.white : _chromeDim,
                  size: 20,
                ),
              ),
              // Episode list (TV) — Baomihua hamburger.
              if (_episodes.isNotEmpty)
                IconButton(
                  key: const Key('player_episode_list'),
                  tooltip: '选集',
                  onPressed: _toggleEpisodePanel,
                  icon: Icon(
                    Icons.menu_rounded,
                    color: _episodePanelOpen ? Colors.white : _chromeDim,
                    size: 22,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileChrome(BuildContext context) {
    // Use a Stack so the middle of the screen stays tappable to dismiss
    // chrome. A full-screen Column was swallowing taps and blocked auto-hide.
    return Stack(
      children: [
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
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
            ),
          ),
        ),
        // Tap empty video area to show/hide chrome (sits under bars).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleControls,
            onDoubleTap: _togglePlay,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: SafeArea(bottom: false, child: _mobileTopBar(context)),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: SafeArea(top: false, child: _mobileBottomBar(context)),
            ),
          ),
        ),
      ],
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
              icon: const Icon(
                Icons.skip_previous_rounded,
                color: Colors.white,
              ),
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
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white70,
                      ),
                      tooltip: 'AI Companion',
                      onPressed: () => unawaited(_openCompanion()),
                    ),
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
                    IconButton(
                      icon: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () => unawaited(_openAudioPanel()),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.subtitles_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () => unawaited(_openSubtitlePanel()),
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
                                        thumbShape: const RoundSliderThumbShape(
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
                                        color: (value - preset).abs() < 0.01
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
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1B23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '倍速  ${_formatRate(_rate)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _speedPresets)
                        ChoiceChip(
                          label: Text(
                            _formatRate(preset),
                            style: TextStyle(
                              color: (_rate - preset).abs() < 0.01
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          selected: (_rate - preset).abs() < 0.01,
                          selectedColor: Colors.white,
                          backgroundColor: const Color(0xFF2A2B33),
                          onSelected: (_) {
                            unawaited(_setRate(preset));
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _optionSheetVisible = false);
    }
  }

  Widget _audioSidePanel() {
    final tracks = _playback.audioTracks;
    final current = _playback.currentAudioTrack;
    return _baomihuaRightDrawer(
      open: _audioPanelOpen,
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _drawerHeader(title: '音轨'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
              children: tracks.isEmpty
                  ? [_drawerHint('未检测到可切换的音轨')]
                  : [
                      for (final track in tracks)
                        _drawerTile(
                          label: _audioTrackLabel(track),
                          selected: track.id == current.id,
                          onTap: () {
                            unawaited(_playback.setAudioTrack(track));
                            setState(() {});
                          },
                        ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtitleSidePanel() {
    final embedded = _playback.subtitleTracks;
    final current = _playback.currentSubtitleTrack;
    final offSelected = current.id == '-1' || current.id.isEmpty;

    final externalTiles = <Widget>[];
    final seen = <String>{};
    for (final sub in _externalSubs) {
      if (!seen.add(sub.uri)) continue;
      final selected = current.uri && current.id == sub.uri;
      externalTiles.add(
        _drawerTile(
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
            setState(() {});
          },
        ),
      );
    }

    return _baomihuaRightDrawer(
      open: _subtitlePanelOpen,
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _drawerHeader(
            title: '字幕',
            trailing: TextButton(
              onPressed: () => unawaited(_pickAndAddSubtitle()),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '+ 手动添加',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
              children: [
                _drawerTile(
                  label: '关闭字幕',
                  selected: offSelected,
                  onTap: () {
                    unawaited(
                      _playback.setSubtitleTrack(PlaybackSubtitleTrack.no()),
                    );
                    setState(() {});
                  },
                ),
                if (embedded.isEmpty &&
                    _externalSubs.isEmpty &&
                    !_externalSubsLoaded)
                  _drawerHint('正在扫描字幕…')
                else if (embedded.isEmpty && _externalSubs.isEmpty)
                  _drawerHint('未检测到字幕（内嵌或同目录外挂）'),
                for (final track in embedded)
                  if (track.id != '-1')
                    _drawerTile(
                      label: _subtitleTrackLabel(track),
                      selected: track.id == current.id,
                      onTap: () {
                        unawaited(_playback.setSubtitleTrack(track));
                        setState(() {});
                      },
                    ),
                ...externalTiles,
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shared Baomihua right drawer chrome (episodes / audio / subtitle).
  Widget _baomihuaRightDrawer({
    required bool open,
    required double width,
    required Widget child,
  }) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          offset: open ? Offset.zero : const Offset(1, 0),
          child: Material(
            color: const Color(0xF0141418),
            elevation: 16,
            child: SizedBox(
              width: width,
              child: SafeArea(left: false, child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerHeader({required String title, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _drawerHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white38, fontSize: 13),
      ),
    );
  }

  Widget _drawerTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndAddSubtitle() async {
    const group = XTypeGroup(
      label: '字幕',
      extensions: ['srt', 'ass', 'ssa', 'vtt', 'sub', 'sup', 'idx'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null || !mounted) return;

    final path = file.path;
    final label = p.basename(path);
    final uri = path.startsWith('/') ? Uri.file(path).toString() : path;

    final external = ExternalSubtitleFile(path: path, label: label);
    setState(() {
      if (!_externalSubs.any((s) => s.uri == external.uri || s.path == path)) {
        _externalSubs = [..._externalSubs, external];
      }
    });
    await _playback.setSubtitleTrack(
      PlaybackSubtitleTrack.uri(uri, title: label),
    );
    if (mounted) {
      setState(() {});
      _showToast('已加载字幕：$label');
    }
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
