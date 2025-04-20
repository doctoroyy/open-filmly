# Application Icons

This directory contains the application icons for Open Filmly in various formats for different platforms.

## Directory Structure

- `/mac/` - macOS icons
  - `icon.icns` - macOS icon bundle

- `/win/` - Windows icons
  - `icon.ico` - Windows icon bundle

- `/linux/` - Linux icons
  - `512x512.png` - High-resolution icon for Linux applications

- `/png/` - PNG icons in various sizes
  - `16x16.png` - 16×16 pixels
  - `24x24.png` - 24×24 pixels
  - `32x32.png` - 32×32 pixels
  - `48x48.png` - 48×48 pixels
  - `64x64.png` - 64×64 pixels
  - `128x128.png` - 128×128 pixels
  - `256x256.png` - 256×256 pixels
  - `512x512.png` - 512×512 pixels
  - `1024x1024.png` - 1024×1024 pixels

## Icon Details

- The macOS icons use the Apple-specific "squircle" shape with rounded corners.
- The Windows icons maintain the original design with appropriate sizes for Windows display.
- PNG versions are available for use in various contexts like documentation and websites.

## Regenerating Icons

To regenerate these icons, use the original icon source in the `/temp/icon-source/` directory and run:

```bash
# For macOS icons with proper rounded corners
node temp/icon-source/process-icon.js
npx electron-icon-maker --input=./temp/icon-source/rounded-icon.png --output=./temp/icons-mac-temp

# For regular icons
npx electron-icon-maker --input=./public/icon.png --output=./temp/icons-temp
```

Then copy the generated icons to their respective directories in the `app-icons` folder. 