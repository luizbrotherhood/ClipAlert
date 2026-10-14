#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ClipAlert"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Closing running instance (if any)..."
killall "${APP_NAME}" 2>/dev/null || true

echo "==> Preparing build directory..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "==> Generating Info.plist..."
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClipAlert</string>
    <key>CFBundleIdentifier</key>
    <string>com.luizbrotherhood.clipalert</string>
    <key>CFBundleName</key>
    <string>ClipAlert</string>
    <key>CFBundleDisplayName</key>
    <string>ClipAlert</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Compiling Swift sources..."
swiftc -O \
    -target arm64-apple-macos11.0 \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework QuartzCore \
    "${SCRIPT_DIR}/Sources/main.swift" \
    "${SCRIPT_DIR}/Sources/AppDelegate.swift" \
    "${SCRIPT_DIR}/Sources/HUDController.swift" \
    "${SCRIPT_DIR}/Sources/ClipboardMonitor.swift" \
    -o "${MACOS_DIR}/${APP_NAME}"

chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "==> Signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Build finished successfully!"
echo "==> App bundle created at: ${APP_BUNDLE}"
