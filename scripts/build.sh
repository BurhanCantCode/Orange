#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${APP_NAME:-Orange}"
APP_EXECUTABLE="${APP_EXECUTABLE:-OrangeApp}"
VERSION="${ORANGE_VERSION:-0.9.0-beta.1}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
BIN_PATH="$ROOT_DIR/apps/desktop/.build/release/${APP_EXECUTABLE}"

mkdir -p "$DIST_DIR"

echo "[build] Building Swift desktop target..."
cd "$ROOT_DIR/apps/desktop"
swift build -c release

if [[ ! -f "$BIN_PATH" ]]; then
  echo "[build] Binary not found at $BIN_PATH"
  exit 1
fi

echo "[build] Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_EXECUTABLE"
chmod +x "$APP_DIR/Contents/MacOS/$APP_EXECUTABLE"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>ai.orange.desktop</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_EXECUTABLE}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
</dict>
</plist>
EOF

if [[ -n "${APPLE_DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "[build] Code signing app bundle..."
  codesign --force --deep --options runtime --sign "$APPLE_DEVELOPER_ID_APPLICATION" "$APP_DIR"
else
  echo "[build] APPLE_DEVELOPER_ID_APPLICATION not set. Skipping code sign."
fi

echo "[build] Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH"

if [[ -n "${APPLE_DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "[build] Code signing DMG..."
  codesign --force --sign "$APPLE_DEVELOPER_ID_APPLICATION" "$DMG_PATH"
fi

echo "[build] Build complete:"
echo "  app: $APP_DIR"
echo "  dmg: $DMG_PATH"
