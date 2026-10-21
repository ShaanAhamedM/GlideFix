#!/bin/bash
set -euo pipefail

PROJECT_DIR="/Users/shaanm/Projects/GlideFix"
APP_BUNDLE="$PROJECT_DIR/GlideFix.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== [1/4] Compiling GlideFix in Release Configuration ==="
swift build -c release --package-path "$PROJECT_DIR"

RELEASE_BIN="$PROJECT_DIR/.build/release/GlideFix"

if [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: Release binary not found at $RELEASE_BIN"
    exit 1
fi

echo "=== [2/4] Constructing macOS App Bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$RELEASE_BIN" "$MACOS_DIR/GlideFix"
chmod +x "$MACOS_DIR/GlideFix"
cp "$PROJECT_DIR/Sources/GlideFixApp/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "=== [3/4] Ad-Hoc Code Signing Bundle ==="
codesign --force --deep --sign - "$APP_BUNDLE"

echo "=== [4/4] Verifying Code Signature ==="
codesign --verify --deep --strict "$APP_BUNDLE"

echo "=========================================================="
echo "SUCCESS! GlideFix.app successfully built and signed at:"
echo "$APP_BUNDLE"
echo "=========================================================="
