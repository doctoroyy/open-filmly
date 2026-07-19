# Open Filmly

[English](README.md) · [简体中文](README.zh-CN.md)

Open Filmly is a local-first, self-hosted, open-source **AI-native personal media OS**. It connects the files you own, the content they contain, your viewing history, and the actions you want to take.

> **Open Filmly 1.0 vision: an open-source AI-native personal media OS for your private library.**

![Open Filmly home](docs/screenshots/home.png)

![Open Filmly TV detail](docs/screenshots/tv-detail.png)

## Product vision

The traditional media-library loop is:

```text
Files → Metadata → Posters → Playback
```

Open Filmly is evolving it into:

```text
Files → AI Understanding → Semantic Index → Personal Memory → AI Agent → Playback
```

The media library should understand people, scenes, places, events, dialogue, emotions, themes, and timelines. It should remember your relationship with what you watch, answer questions in context, and help you act on your library. You should be able to search by what happened in a scene, ask questions while watching, and jump directly to the matching moment.

Our product principles:

- **Local first**: media files, indexes, and viewing memory stay on your devices and storage by default.
- **Progressive AI**: make subtitles, search, and in-player assistance excellent before expanding into recommendations and automation.
- **Timeline first**: every understanding result should map to a playable segment, screenshot, and timestamp whenever possible.
- **Spoiler safe**: AI Companion answers from the part of the story the viewer has already watched.
- **User controlled**: AI proposes actions and previews; it never moves, deletes, or rewrites media files without confirmation.

## AI roadmap — next 3–6 months

The roadmap focuses on three capabilities that can make Open Filmly immediately recognizable: **AI subtitles, Ask Filmly, and spoiler-safe AI Companion**.

| Priority | Direction | User experience | Planned output |
| --- | --- | --- | --- |
| P0 | AI subtitles | Transcription, translation, timing, correction, and bilingual display | Local or optional cloud ASR, subtitle timeline editing, context-aware names and terms |
| P0 | Ask Filmly | Search movies, dialogue, people, and scenes in natural language, then jump to the timestamp | Cmd/Ctrl + K entry point, semantic retrieval, timestamped results, screenshots, one-click playback |
| P1 | AI Companion | Ask “Who is he?”, “What happened before?”, or “Why did they say that?” while watching | Current-progress awareness, contextual answers, spoiler boundaries, linked rewatch moments |
| P1 | AI collections and recommendations | “Cyberpunk but not too heavy” or “What can I watch tonight in two hours?” | Editable collections generated from content, viewing history, and current intent |
| P2 | Personal Film Memory | Remember what you watched, liked, revisited, and where you stopped | Viewing memory, thematic retrospectives, cross-device sync, privacy controls |
| P2 | Media Agent | Batch-generate subtitles, find duplicates, audit quality, and surface unwatched downloads | Previewable plans, task queues, backups, and reversible file operations |

### Phase 1: make watching better

AI subtitles are the most direct entry point. The goal is not just speech recognition, but subtitles that are genuinely good to watch:

- Transcribe speech, generate subtitles, and align the timeline automatically.
- Translate into Chinese or another target language with bilingual display.
- Keep names, places, and specialized terms consistent using the film context.
- Detect intros, outros, recaps, ads, and post-credit scenes for smart skipping.
- Explain cultural references or translation choices in the player without spoiling the story.

### Phase 2: Ask Filmly

You should not need to remember a title or filename. Describe what you want to find:

```text
Find the movie where the male lead waits for her in the rain.
Find every film about an AI going out of control.
Find scenes with New York at night in my favorites.
Find dialogue about time across Nolan's films.
```

Results should include the title, scene, timestamp, screenshot, and an explanation of why it matches. One click should start playback at that moment. Ask Filmly is intended to become a primary way to enter the library, not another filter beside a title search box.

### Phase 3: AI Companion

AI Companion is for questions that arise during playback:

```text
Who is he?
Has this object appeared before?
Why is she angry?
What happened earlier?
```

Answers must be grounded in the current playback position and only use information the viewer has already reached. If the viewer pauses at a character’s first appearance, the assistant can explain the known identity and earlier context without revealing what happens later.

## Current capabilities

- Separate shelves for movies, TV shows, anime, variety, concerts, documentaries, and more.
- TMDB metadata, posters, backdrops, cast, and episode information.
- Recently watched, resume progress, favorites, global search, and automatic scanning.
- Season-tab TV details with 16:9 episode still cards.
- Local folders, SMB, WebDAV, Emby, and Jellyfin media sources.
- Resource-source management: add, edit, import, and remove network resources while keeping local and remote sources distinct.
- Cross-device database import/export with data-preserving app upgrades.
- Numeric episode filename recognition, AppleDouble sidecar cleanup, legacy episode repair, and duplicate TV-card consolidation.
- Native playback with VLCKit 3.7.3 on macOS, libVLC on Windows and Android, and MobileVLCKit on iOS.
- Hardware decoding, audio and subtitle tracks, external subtitles, buffering, seeking, speed, volume, next/previous episode, and autoplay.
- macOS and Windows window dragging, double-click maximize, fullscreen, and desktop keyboard shortcuts.
- Compact mobile navigation, mobile double-tap gestures, and immersive playback interactions.

## Platform status

| Platform | Status | Notes |
| --- | --- | --- |
| macOS | Runnable | Native VLCKit 3.7.3 playback with a sandboxed database |
| Windows | Runnable | Windows Runner with native libVLC playback |
| iOS | Runnable | iOS Runner, system file import, MobileVLCKit playback, and database migration |
| Android | Runnable | Android Runner, system file import, and libVLC playback |

## Technical direction

### Media understanding layer

As a video is imported, Open Filmly will progressively build structured information:

```text
Film
├── People and relationships
├── Scenes, places, and events
├── Dialogue and subtitle timeline
├── Emotions, themes, and key concepts
└── Screenshots, vector indexes, and playable timestamps
```

The implementation will favor replaceable components that can run locally: speech transcription, subtitle translation, visual understanding, vector indexing, and optional remote models. Without an AI service, the core library and player remain fully usable.

### Agent safety boundaries

Any automation that affects files or the library follows this sequence:

1. Analyze the request and show a plan.
2. Let the user preview and adjust the scope.
3. Ask for explicit confirmation before execution.
4. Keep a backup or provide a way to undo the change.

## Development

```bash
flutter pub get
flutter run -d macos
# Windows host: flutter run -d windows
# iOS: flutter run -d <ios-device-id>
# Android: flutter run -d <android-device-id>
```

Quality checks:

```bash
flutter analyze lib
flutter test $(ls test/*.dart | grep -v integration_smb_real | grep -v ui_automation)
flutter build macos --release
flutter build apk --debug
flutter build ios --simulator
```

Environment-dependent tests:

- `integration_smb_real_test.dart` requires an accessible SMB service on the local network.
- `ui_automation_test.dart` requires a running app and Flutter VM Service.

## Contributing to the roadmap

The most useful contribution areas right now are:

- AI subtitle pipeline: ASR, translation, timeline alignment, and subtitle editing.
- Multimodal indexing: one data model for dialogue, visuals, screenshots, and playback timestamps.
- Ask Filmly: natural-language retrieval, result explanations, and timeline jumps.
- AI Companion: current-progress awareness and spoiler-safe context windows.
- Local model adapters: core AI features without uploading video files.
- Cross-platform UX: consistent capabilities across macOS, Windows, iOS, and Android while respecting each platform’s strengths.

## Tech stack

- UI: Flutter, Material 3
- State management: Riverpod
- Routing: `go_router`
- Playback: VLCKit 3.7.3 (macOS), libVLC (Windows and Android), MobileVLCKit (iOS)
- Database: Drift / SQLite
- Network media: SMB Range proxy, WebDAV, Emby / Jellyfin
- Desktop windows: `window_manager` with native macOS / Windows window bridges

---

Open Filmly is not trying to be another Plex, Jellyfin, or media player. It is building an AI-native personal media OS: a private layer of understanding, memory, and agency across the media you own.
