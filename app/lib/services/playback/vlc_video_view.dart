import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'playback_service.dart';

class VlcVideoView extends StatelessWidget {
  const VlcVideoView({
    super.key,
    required this.service,
    required this.nativeOverlayInsets,
  });

  final PlaybackService service;
  final EdgeInsets nativeOverlayInsets;

  @override
  Widget build(BuildContext context) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => AppKitView(
        viewType: 'open_filmly/vlc_player_view',
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        creationParams: const <String, Object?>{},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (viewId) {
          unawaited(service.attachNativeView(viewId));
        },
      ),
      TargetPlatform.windows => _WindowsVlcVideoView(
        service: service,
        nativeOverlayInsets: nativeOverlayInsets,
      ),
      _ => const ColoredBox(color: Colors.black),
    };
  }
}

class _WindowsVlcVideoView extends StatefulWidget {
  const _WindowsVlcVideoView({
    required this.service,
    required this.nativeOverlayInsets,
  });

  final PlaybackService service;
  final EdgeInsets nativeOverlayInsets;

  @override
  State<_WindowsVlcVideoView> createState() => _WindowsVlcVideoViewState();
}

class _WindowsVlcVideoViewState extends State<_WindowsVlcVideoView>
    with WidgetsBindingObserver {
  static int _nextViewId = 1;

  final _surfaceKey = GlobalKey();
  late final int _viewId = _nextViewId++;
  Rect? _lastBounds;
  double? _lastDevicePixelRatio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.service.attachNativeView(_viewId));
    _scheduleBoundsSync();
  }

  @override
  void didUpdateWidget(covariant _WindowsVlcVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nativeOverlayInsets != widget.nativeOverlayInsets) {
      _lastBounds = null;
    }
    _scheduleBoundsSync();
  }

  @override
  void didChangeMetrics() {
    _lastBounds = null;
    _scheduleBoundsSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleBoundsSync();
    return ColoredBox(key: _surfaceKey, color: Colors.black);
  }

  void _scheduleBoundsSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncBounds();
    });
  }

  void _syncBounds() {
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final insets = widget.nativeOverlayInsets;
    final visibleWidth = (size.width - insets.left - insets.right).clamp(
      0.0,
      double.infinity,
    );
    final visibleHeight = (size.height - insets.top - insets.bottom).clamp(
      0.0,
      double.infinity,
    );
    final bounds = Rect.fromLTWH(
      origin.dx + insets.left,
      origin.dy + insets.top,
      visibleWidth,
      visibleHeight,
    );
    final devicePixelRatio = View.of(context).devicePixelRatio;

    if (_lastBounds == bounds && _lastDevicePixelRatio == devicePixelRatio) {
      return;
    }
    _lastBounds = bounds;
    _lastDevicePixelRatio = devicePixelRatio;

    unawaited(
      widget.service.setNativeBounds(
        bounds,
        devicePixelRatio: devicePixelRatio,
      ),
    );
  }
}
