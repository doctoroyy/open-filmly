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
- **Backend**: Electron main process with SQLite database and multiple service modules
- **Communication**: IPC between renderer and main processes

### Backend Services (electron/ directory)
- **main.ts** - Application entry point, window management, IPC orchestration
- **media-database.ts** - SQLite persistence layer using better-sqlite3
- **media-scanner.ts** - File system scanning and media classification
- **metadata-scraper.ts** - TMDB API integration for enriching media metadata
- **smb-client.ts** - SMB/CIFS network storage client
- **server.ts** - Production HTTP server using Hono framework

### Frontend Structure (src/ directory)
- **router/** - File-based routing system
- **pages/** - Route components (index, movies, tv, config, media-list)
- **components/** - Reusable UI components (media cards, grids, file browser)
- **lib/api.ts** - TMDB API client and IPC communication utilities

### Data Flow Patterns

**Media Scanning Pipeline:**
1. SMB client discovers network shares and files
2. File parser extracts metadata from paths/filenames
3. Media scanner classifies files as movies/TV shows
4. Database stores basic file information
5. Metadata scraper enriches data via TMDB API
6. Frontend displays organized media library

**Configuration Management:**
- User settings persist in SQLite config table
- TMDB API keys managed at runtime
- Network storage credentials stored securely
- Folder selection for targeted scanning

### Network Storage Integration
SMB/CIFS support for accessing NAS devices with path conversion between Unix/Windows formats, connection pooling, and auto-discovery of common share names.

### Database Schema
SQLite with dynamic schema updates for backwards compatibility. Core tables include media files and application configuration.

### Build System
- Vite for frontend bundling
- TypeScript compilation for Electron main process
- electron-builder for cross-platform distribution
- GitHub Actions workflow for automated releases on git tags

### Development Notes
- IPC handlers in main.ts provide clean API between processes
- Media type classification uses both path analysis and TMDB search results
- Poster images cached locally for offline access
- Error handling includes graceful degradation for network issues