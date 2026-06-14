import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'playback_service.dart';

class VlcVideoView extends StatelessWidget {
  const VlcVideoView({super.key, required this.service});

  final PlaybackService service;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return const ColoredBox(color: Colors.black);
    }

    return AppKitView(
      viewType: 'open_filmly/vlc_player_view',
      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      creationParams: const <String, Object?>{},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (viewId) {
        unawaited(service.attachNativeView(viewId));
      },
    );
  }
}
