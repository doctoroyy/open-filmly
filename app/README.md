# Open Filmly App

This directory contains the cross-platform Flutter client for Open Filmly.

## Directory map

- `lib/features/home`: library dashboard and shelves.
- `lib/features/library`: poster wall, favorites, and detail pages.
- `lib/features/player`: native VLC-backed player UI and controls.
- `lib/features/sources`: local, SMB, WebDAV, Emby, and Jellyfin-style source setup.
- `lib/data`: Drift database, models, and repositories.
- `lib/services/playback`: Dart playback facade and native VLC video views.
- `lib/services/smb`: SMB client wrapper plus local HTTP Range proxy.
- `macos/Runner/AppDelegate.swift`: native VLCKit bridge and window channel.
- `windows/runner/vlc_player_win.cpp`: native Windows libVLC bridge and window channel.
- `ios/` and `android/`: mobile runners backed by MobileVLCKit / libVLC.
- `packages/smb_connect`: bundled SMB client package.
- `test/`: widget, repository, metadata, source, and playback resolver tests.

## Run

```bash
flutter pub get
flutter run -d macos
# flutter run -d <ios-device-id>
# flutter run -d <android-device-id>
```

## Verification

```bash
flutter analyze
flutter test $(ls test/*.dart | grep -v integration_smb_real | grep -v ui_automation)
flutter build ios --simulator
flutter build apk --debug
flutter build macos --release
```

## Playback

Playback uses native `VLCKit` / `libVLC` on macOS, Windows, iOS, and Android.
The player supports embedded audio and subtitle tracks, UTF-8-normalized local
and network sidecar subtitles, hardware decoding, and VLC network/file cache
options. SMB video ranges are streamed through the local proxy in large chunks
so playback is not limited by tiny sequential reads.

On Windows, install VLC from VideoLAN or bundle the VLC runtime beside
`open_filmly.exe` under `vlc/`.
