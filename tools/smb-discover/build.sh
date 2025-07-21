#!/bin/bash

# Build script for SMB Discovery Tool
set -e

echo "Building SMB Discovery Tool..."

# Create bin directory if it doesn't exist
mkdir -p bin

# Get the current platform
CURRENT_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
CURRENT_ARCH=$(uname -m)

# Normalize architecture
case $CURRENT_ARCH in
    x86_64)
        CURRENT_ARCH="amd64"
        ;;
    arm64)
        CURRENT_ARCH="arm64"
        ;;
    aarch64)
        CURRENT_ARCH="arm64"
        ;;
esac

echo "Detected platform: $CURRENT_OS-$CURRENT_ARCH"

# Build for current platform first
echo "Building for current platform..."
go build -o "bin/smb-discover-$CURRENT_OS-$CURRENT_ARCH" main.go

# Build for all common platforms
echo "Cross-compiling for all platforms..."

# macOS Intel
echo "  Building for macOS Intel..."
GOOS=darwin GOARCH=amd64 go build -o bin/smb-discover-darwin-amd64 main.go

# macOS Apple Silicon
echo "  Building for macOS Apple Silicon..."
GOOS=darwin GOARCH=arm64 go build -o bin/smb-discover-darwin-arm64 main.go

# Windows 64-bit
echo "  Building for Windows 64-bit..."
GOOS=windows GOARCH=amd64 go build -o bin/smb-discover-windows-amd64.exe main.go

# Linux 64-bit
echo "  Building for Linux 64-bit..."
GOOS=linux GOARCH=amd64 go build -o bin/smb-discover-linux-amd64 main.go

# Linux ARM64
echo "  Building for Linux ARM64..."
GOOS=linux GOARCH=arm64 go build -o bin/smb-discover-linux-arm64 main.go

echo "Build complete! Binaries available in bin/ directory:"
ls -la bin/

echo ""
echo "Current platform binary: bin/smb-discover-$CURRENT_OS-$CURRENT_ARCH"