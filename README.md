# Open Filmly

Open Filmly is a powerful media management platform similar to Plex, Emby, or Jellyfin, designed to organize and stream your media library. It automatically categorizes your media files, fetches posters and metadata, tracks playback progress, and supports one-click playback with automatic subtitle matching.

**⚠️ BETA STATUS:** Open Filmly is currently in beta. Some features are still under development and may not be fully functional.

## Features

- ✅ Automatic media scanning and categorization
- ✅ Metadata and poster fetching from online sources
- 🚧 One-click playback with integrated media player (in development)
- 🚧 Automatic subtitle detection and matching (planned)
- 🚧 Watch progress tracking (in development)
- ✅ NAS/Samba connectivity for accessing network storage
- ✅ Electron-based cross-platform support

*Legend: ✅ Completed | 🚧 In Development*

## Project Status

Open Filmly is currently in active development. Core functionality for media scanning, categorization, and metadata fetching is working. The media player integration, subtitle matching, and watch progress tracking features are still being developed.

### Roadmap:
- Complete the media player integration
- Implement subtitle auto-detection and matching
- Add user watch history and progress tracking
- Improve UI/UX for the media browsing experience
- Add user profiles and preferences

## Development

This project uses pnpm as the package manager. Make sure to install pnpm first:

```bash
npm install -g pnpm
```

### Install dependencies

```bash
pnpm install
```

### Run in development mode

For frontend development only:
```bash
pnpm dev
```

For full Electron app development:
```bash
pnpm dev:electron
```

This will start both the Vite development server and the Electron app with hot reload.

### Build for production

```bash
pnpm build
pnpm dist
```

The `dist` command will clean, build, and create distributable packages for all platforms.

## Requirements

- Node.js 16+
- pnpm 7+

## Tech Stack

- **Frontend**: React + TypeScript + Vite
- **Backend**: Electron main process with Node.js
- **Database**: SQLite with better-sqlite3
- **UI**: Tailwind CSS + Radix UI components
- **Network Storage**: SMB/CIFS client for NAS access
- **Metadata**: TMDB API integration
- **Build**: electron-builder for cross-platform packaging

## Project Structure

- `/src` - React frontend application
  - `/components` - Reusable UI components
  - `/pages` - Route components
  - `/lib` - Utility functions and API clients
  - `/types` - TypeScript type definitions
- `/electron` - Electron main process code
  - `main.ts` - Application entry point and IPC handlers
  - `media-database.ts` - SQLite database layer
  - `media-scanner.ts` - Media file scanning and classification
  - `metadata-scraper.ts` - TMDB API integration
  - `smb-client.ts` - SMB/CIFS network storage client
- `/public` - Static assets and app icons
- `/types` - Shared TypeScript definitions 
