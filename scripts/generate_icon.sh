#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_PNG="$ROOT_DIR/website/public/orange_favicon.png"
OUTPUT_ICNS="$ROOT_DIR/apps/desktop/Sources/OrangeApp/Resources/AppIcon.icns"
TMPDIR_ICON=$(mktemp -d)
ICONSET_DIR="$TMPDIR_ICON/AppIcon.iconset"

if [[ ! -f "$SOURCE_PNG" ]]; then
  echo "[icon] Source PNG not found: $SOURCE_PNG"
  exit 1
fi

echo "[icon] Generating .icns from $SOURCE_PNG..."
mkdir -p "$ICONSET_DIR"

# Convert source to proper PNG with alpha channel
CONVERTED="$TMPDIR_ICON/source.png"
sips -s format png -s formatOptions best "$SOURCE_PNG" --out "$CONVERTED" > /dev/null 2>&1

gen() {
  local size=$1 name=$2
  sips -z "$size" "$size" "$CONVERTED" --out "$ICONSET_DIR/$name" > /dev/null 2>&1
}

gen 16   "icon_16x16.png"
gen 32   "icon_16x16@2x.png"
gen 32   "icon_32x32.png"
gen 64   "icon_32x32@2x.png"
gen 128  "icon_128x128.png"
gen 256  "icon_128x128@2x.png"
gen 256  "icon_256x256.png"
gen 512  "icon_256x256@2x.png"
gen 512  "icon_512x512.png"
gen 1024 "icon_512x512@2x.png"

mkdir -p "$(dirname "$OUTPUT_ICNS")"
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
rm -rf "$TMPDIR_ICON"

echo "[icon] Created $OUTPUT_ICNS"
