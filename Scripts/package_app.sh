#!/bin/bash
set -euo pipefail

PROJECT_DIR="/Users/shaanm/Projects/GlideFix"
APP_BUNDLE="$PROJECT_DIR/GlideFix.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS="$PROJECT_DIR/GlideFix.entitlements"

echo "=== [1/5] Compiling GlideFix in Release Configuration ==="
swift build -c release --package-path "$PROJECT_DIR"

RELEASE_BIN="$PROJECT_DIR/.build/release/GlideFix"

if [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: Release binary not found at $RELEASE_BIN"
    exit 1
fi

echo "=== [2/5] Constructing macOS App Bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$RELEASE_BIN" "$MACOS_DIR/GlideFix"
chmod +x "$MACOS_DIR/GlideFix"
cp "$PROJECT_DIR/Sources/GlideFixApp/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "=== [3/5] Applying Hardened Runtime & Signing with Entitlements ==="
codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" -r='designated => identifier "com.glidefix.GlideFix"' --sign - "$APP_BUNDLE"

echo "=== [4/5] Cryptographic & Entitlements Verification ==="
codesign -dvvv --entitlements - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "=== [5/5] Dynamic Library Dependency Audit ==="
otool -L "$MACOS_DIR/GlideFix"

echo "=========================================================="
echo "SUCCESS! Hardened GlideFix.app successfully built & verified at:"
echo "$APP_BUNDLE"
echo "=========================================================="
