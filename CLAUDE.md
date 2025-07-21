# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development
- `pnpm dev` - Start Vite development server (frontend only)
- `pnpm dev:electron` - Start full Electron app with hot reload (frontend + Electron)
- `pnpm start` - Run built Electron app

### Building
- `pnpm build` - Build frontend and compile TypeScript for Electron
- `pnpm dist` - Clean, build, and create distributable packages
- `pnpm pack` - Create packaged app without installer
- `pnpm clean` - Remove dist directory

### Package Manager
This project uses **pnpm** exclusively. Node.js 16+ required.

## Architecture Overview

### Multi-Process Electron Application
Open Filmly is an Electron-based media management platform with a React frontend and Node.js backend services running in the main process.

**Key Components:**
- **Frontend**: React + Vite + TypeScript in renderer process
- **Backend**: Electron main process with SQLite database and pluggable provider system
- **Communication**: Type-safe IPC architecture between renderer and main processes

### Provider-Based Architecture
The application uses a pluggable provider system for extensibility:

**Storage Providers** (`electron/providers/storage/`):
- **SMB Provider** - Network storage via SMB/CIFS protocol with Go binary for discovery
- Extensible for FTP, NFS, WebDAV, etc.

**Media Player Providers** (`electron/providers/player/`):
- **MPV Provider** - Integration with MPV media player
- **System Provider** - Fallback to system default players
- Extensible for VLC, browser-based players, etc.

### Backend Services (electron/ directory)
- **main.ts** - Application entry point, window management, IPC orchestration
- **media-database.ts** - SQLite persistence layer using better-sqlite3
- **auto-scan-manager.ts** - Automated media scanning and monitoring
- **metadata-scraper.ts** - TMDB API integration with intelligent name recognition
- **network-storage-client.ts** - Unified client for network storage providers
- **media-player-client.ts** - Unified client for media player providers
- **provider-factory.ts** - Factory for creating provider instances
- **media-proxy-server.ts** - HTTP proxy server for streaming media files

### IPC Communication Architecture
Type-safe IPC system with centralized channel definitions:
- **ipc-channels.ts** - Centralized channel definitions (no string hardcoding)
- **ipc-handler.ts** - Type-safe handler registration framework
- **ipc-client.ts** - Client-side API classes with full type safety
- **ipc-handlers.ts** - Concrete handler implementations
- See `electron/IPC_ARCHITECTURE.md` for detailed documentation

### Frontend Structure (src/ directory)
- **router/** - File-based routing system
- **pages/** - Route components (index, movies, tv, config, media-list, debug)
- **components/** - Reusable UI components with Radix UI + Tailwind CSS
- **lib/api.ts** - TMDB API client and IPC communication utilities
- **types/electron.d.ts** - TypeScript definitions for Electron API

### Data Flow Patterns

**Media Scanning Pipeline:**
1. Network storage provider discovers shares and files via Go binaries
2. Auto-scan manager monitors configured directories
3. File parser extracts metadata from paths/filenames using intelligent recognition
4. Media scanner classifies files as movies/TV shows
5. Database stores file information with dynamic schema updates
6. Metadata scraper enriches data via TMDB API and Gemini AI
7. Frontend displays organized media library with posters

**Configuration Management:**
- Unified `host` field supports IP addresses, hostnames, and domain names
- User settings persist in SQLite config table with backwards compatibility
- TMDB and Gemini API keys managed at runtime
- Network storage credentials stored securely
- Folder selection for targeted scanning

### Network Storage Integration
SMB/CIFS support via Go binaries for cross-platform compatibility:
- **smb-discover** Go binary for share discovery and connection testing
- Path conversion between Unix/Windows formats
- Connection pooling and error handling
- Auto-discovery of common share names and NAS devices

### Database Schema
SQLite with dynamic schema updates for backwards compatibility. Core tables include media files, configuration, and metadata cache.

### External Tools Integration
- **Go Binaries** (`tools/smb-discover/`) - Cross-platform SMB discovery
- **TMDB API** - Movie/TV metadata and poster fetching
- **Gemini AI** - Intelligent media file name recognition
- **MPV Player** - Media playback integration

### Build System
- Vite for frontend bundling with hot reload
- TypeScript compilation for Electron main process
- electron-builder for cross-platform distribution (Windows, macOS, Linux)
- GitHub Actions workflow for automated releases on git tags

### Development Notes
- All network configuration uses unified `host` field (not `ip`) for flexibility
- Provider system allows easy extension for new storage protocols and players
- IPC handlers provide clean, type-safe API between processes
- Media type classification uses both path analysis and TMDB search results
- Poster images cached locally for offline access
- Error handling includes graceful degradation for network issues
- Go binaries automatically built for target platforms (darwin-arm64, etc.)
- **All code comments and developer messages must be in English** - no Chinese comments in codebase