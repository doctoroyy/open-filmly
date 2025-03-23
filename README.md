# Open Filmly

Open Filmly is an Electron-based app for managing and viewing your media library from NAS devices.

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