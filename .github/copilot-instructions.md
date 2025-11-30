# Open Filmly - AI Coding Agent Guide

## Project Overview
Open Filmly is an Electron-based media management platform (like Plex/Jellyfin) with React frontend, Node.js backend, and pluggable provider architecture for storage protocols (SMB/NFS/FTP) and media players (MPV/System).

## Critical Architecture Patterns

### Multi-Process Electron Design
- **Renderer Process**: React + Vite + TypeScript (`src/`)
- **Main Process**: Node.js services, SQLite database, provider system (`electron/`)
- **Communication**: Type-safe IPC via centralized channel definitions (`electron/ipc-channels.ts`)

**Never hardcode IPC channel strings** - always use constants from `IPCChannels` object:
```typescript
// ❌ Wrong
ipcRenderer.invoke('media:get')

// ✅ Correct
ipcRenderer.invoke(IPCChannels.GET_MEDIA)
```

### Provider-Based Extensibility
Storage and player functionality uses factory pattern (`electron/provider-factory.ts`):
- **Storage Providers** (`electron/providers/storage/`): SMB, FTP, NFS, WebDAV
- **Player Providers** (`electron/providers/player/`): MPV, System default
- All providers implement interfaces from `electron/types/providers.ts`

When adding new providers: implement interface → register in factory → update type unions.

### File-Based Routing
Frontend uses convention-based routing (`src/router/generator.ts`):
- Place component in `src/pages/` → auto-registered as route
- `[id].tsx` becomes `:id` dynamic route
- `index.tsx` becomes root path `/`

## Developer Workflows

### Essential Commands
```bash
pnpm dev              # Frontend only (Vite dev server)
pnpm dev:electron     # Full app with hot reload
pnpm build            # Build all + compile SMB Go binaries
pnpm build:smb        # Just compile cross-platform Go tools
pnpm dist             # Production packages for all platforms
```

**Important**: `pnpm` is required (not npm/yarn). Node.js 16+ required.

### SMB Tools Build System
Go binaries (`tools/smb-tools/`) handle cross-platform SMB operations:
- Compiled automatically during production builds (not dev)
- Binary naming: `smb-tools-{platform}-{arch}` (e.g., `smb-tools-darwin-arm64`)
- Commands: `discover`, `list`, `test` for SMB operations
- Build script: `tools/smb-tools/build.sh` creates all platform variants

### Database Schema Evolution
SQLite with dynamic migrations in `media-database.ts`:
```typescript
// Check for column existence before adding
const tableInfo = this.db.prepare("PRAGMA table_info(media)").all()
if (!tableInfo.some(col => col.name === 'newColumn')) {
  this.db.exec("ALTER TABLE media ADD COLUMN newColumn TEXT")
}
```
Always maintain backwards compatibility - check before altering.

## Code Conventions

### Language Policy
**All code comments and developer messages MUST be in English** - no Chinese comments in codebase (Chinese is acceptable only in user-facing UI strings).

### IPC Communication Pattern
3-layer type-safe system:
1. **Define channels** in `ipc-channels.ts` with request/response types
2. **Implement handlers** in `ipc-handlers.ts` using `registerIPCHandler()`
3. **Create client API** in `ipc-client.ts` for renderer process

See `electron/IPC_ARCHITECTURE.md` for detailed examples.

### Network Configuration
Always use unified `host` field (not `ip`) for flexibility with IP addresses, hostnames, and domains. Example:
```typescript
interface NetworkStorageConfig {
  host: string  // ✅ Supports "192.168.1.1" | "nas.local" | "storage.example.com"
  // ❌ Don't use 'ip' field
}
```

### Media Scanning Pipeline
1. Network storage provider discovers files via Go binaries
2. `AutoScanManager` monitors configured directories
3. `IntelligentNameRecognizer` (Gemini AI) extracts metadata from filenames
4. `MediaDatabase` stores with dynamic schema
5. `MetadataScraper` enriches via TMDB API
6. Frontend displays organized library

Track progress via `TaskQueueManager` and emit events to renderer process.

## Key Integration Points

### TMDB API Client
`src/lib/api.ts` handles metadata:
- API key retrieved dynamically via IPC (`getTmdbApiKey()`)
- Falls back to `VITE_TMDB_API_KEY` env var in development
- Language hardcoded to 'zh-CN' for Chinese metadata

### Gemini AI Integration
`IntelligentNameRecognizer` uses Gemini 2.0 Flash for filename parsing:
- Combines Jina search results for context
- Returns structured `MediaNameRecognitionResult` with confidence scores
- Batch processing available via `intelligentBatchRecognize()`

### MPV Player Setup
Complex PPAPI plugin initialization in `electron/main.ts`:
- Dynamic path discovery for `mpv.js` module
- Prebuilt binary extraction from platform-specific tarballs
- Command-line switches for plugin support and web security bypass

## Common Pitfalls

1. **Binary bloat**: Go binaries excluded from git (`.gitignore`), compiled at build time
2. **Path handling**: Windows/Unix path conversion in SMB provider (`convertToWindowsPath()`)
3. **Provider errors**: Use `ProviderError` class with error codes for debugging
4. **IPC timeouts**: Long operations should use background tasks with progress events
5. **Hot reload**: Electron main process requires restart even in dev mode (limitation of `dev:electron`)

## Testing & Debugging

- **Frontend**: Check browser DevTools in Electron window
- **Main Process**: Console output shows `[IPC]` prefixed logs for all IPC calls
- **Provider Testing**: Use `electron/providers/*/test.ts` scripts
- **Database Inspection**: SQLite DB at `~/.open-filmly/media.db` (path varies by OS)

## External Dependencies

- **better-sqlite3**: Must be excluded from Vite bundling (see `vite.config.ts`)
- **Radix UI**: Component library for frontend (see `components/ui/`)
- **Tailwind CSS**: Styling via utility classes
- **electron-builder**: Packaging config in `package.json` → `build` section

## Recent Major Changes

- ✅ Removed `media-proxy-server.ts` (replaced with native MPV)
- ✅ Unified `smb-discover` → `smb-tools` with full SMB functionality
- ✅ Migrated from `ip` to `host` field in network config
- ✅ Implemented automatic SMB binary compilation in production builds
- ✅ Added file hash deduplication via `HashService`

---

**When in doubt**, check existing patterns in `electron/ipc-handlers.ts` for IPC methods, `electron/providers/` for provider implementations, or `CLAUDE.md` for additional context.
