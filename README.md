# Open Filmly

Open Filmly is a desktop media library player for macOS. It is now a Flutter
application backed by native VLCKit playback, replacing the old Electron code.

The app is built for private media libraries: local folders, SMB shares,
WebDAV servers, Emby, and Jellyfin-style sources. It scans media, cleans file
names, enriches titles through TMDB, tracks playback progress, and plays video
inside the app with VLC's codec, audio-track, and embedded-subtitle support.

## Screenshots

![Home library](docs/screenshots/home.png)

![VLCKit player](docs/screenshots/player.png)

## What works

- macOS desktop client built with Flutter.
- Native embedded VLC player through `VLCKit`.
- Local file, HTTP, WebDAV, and SMB playback.
- SMB streaming through a local HTTP Range proxy.
- Emby library import and browsing.
- TMDB metadata matching, poster walls, favorites, recent playback, and
  continue-watching shelves.
- Embedded audio and subtitle track discovery with Chinese subtitle preference.
- macOS window controls, safe-area spacing, keyboard shortcuts, and double-click
  fullscreen on the video surface.

## Repository layout

- `app/` contains the Flutter application.
- `app/macos/` contains the macOS host app and the VLCKit bridge.
- `app/packages/smb_connect/` is the local SMB client package used by the app.
- `docs/screenshots/` contains README screenshots.

The legacy Electron, Vite, React, Node, and Go desktop code has been removed
from the main branch.

## Requirements

- macOS 13 or newer recommended.
- Flutter 3.44 or newer.
- Xcode command line tools.
- CocoaPods, used to install `VLCKit`.

Install CocoaPods if needed:

```bash
sudo gem install cocoapods
```

## Run locally

```bash
cd app
flutter pub get
cd macos && pod install && cd ..
flutter run -d macos
```

## Build

```bash
cd app
flutter pub get
cd macos && pod install && cd ..
flutter build macos --release
scripts/make_dmg.sh build/Open-Filmly.dmg
```

The release app is written to:

```text
app/build/macos/Build/Products/Release/open_filmly.app
```

## Verification

```bash
cd app
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build macos --debug
```

## Real SMB test

The normal test suite does not require a real NAS. To run the optional real SMB
test, set these variables first:

```bash
export OPEN_FILMLY_REAL_SMB_HOST=192.168.1.10
export OPEN_FILMLY_REAL_SMB_USERNAME=username
export OPEN_FILMLY_REAL_SMB_PASSWORD=password
export OPEN_FILMLY_REAL_SMB_SHARE=Movies
export OPEN_FILMLY_REAL_SMB_DOMAIN=

cd app
flutter test test/integration_smb_real_test.dart
```

## VLCKit note

VLCKit is distributed through CocoaPods and is licensed under LGPL terms. Keep
the framework dynamically linked and preserve the license obligations when
packaging the app.
