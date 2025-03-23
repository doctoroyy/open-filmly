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

```bash
pnpm dev
```

This will start both the Next.js frontend and the Electron app.

### Build for production

```bash
pnpm build
pnpm dist
```

## Requirements

- Node.js 16+
- pnpm
- For Samba connectivity, smbclient must be installed on your system
  - On Ubuntu/Debian: `sudo apt-get install smbclient`
  - On macOS: `brew install samba`

## Project Structure

- `/app` - Next.js application
- `/electron` - Electron main process code
- `/components` - React components
- `/types` - TypeScript type definitions 