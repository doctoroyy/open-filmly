# Open Filmly App

This directory contains the Flutter macOS client for Open Filmly.

## Directory map

- `lib/features/home`: library dashboard and shelves.
- `lib/features/library`: poster wall, favorites, and detail pages.
- `lib/features/player`: VLCKit-backed player UI and controls.
- `lib/features/sources`: local, SMB, WebDAV, Emby, and Jellyfin-style source setup.
- `lib/data`: Drift database, models, and repositories.
- `lib/services/playback`: Dart playback facade and macOS VLC platform view.
- `lib/services/smb`: SMB client wrapper plus local HTTP Range proxy.
- `macos/Runner/AppDelegate.swift`: native VLCKit bridge and window channel.
- `packages/smb_connect`: bundled SMB client package.
- `test/`: widget, repository, metadata, source, and playback resolver tests.

## Run

```bash
flutter pub get
cd macos && pod install && cd ..
flutter run -d macos
```

## Verification

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build macos --debug
```

## Playback

Playback uses native `VLCKit` on macOS. The player supports embedded subtitle
and audio tracks, preloads with VLC network/file cache options, and maps
double-click on the video surface to macOS fullscreen.
