#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Multigravity"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "==> Building ${APP_NAME}..."
mkdir -p "${MACOS_DIR}"

clang -O2 -framework Cocoa src/main.m -o "${MACOS_DIR}/Multigravity"

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Multigravity</string>
    <key>CFBundleIdentifier</key>
    <string>com.adalenv.multigravity</string>
    <key>CFBundleName</key>
    <string>Multigravity</string>
    <key>CFBundleDisplayName</key>
    <string>Multigravity</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

chmod +x "${MACOS_DIR}/Multigravity"
echo "==> Build successful: ${APP_DIR} is ready!"
