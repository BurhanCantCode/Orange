#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${APP_NAME:-Orange}"
VERSION="${ORANGE_VERSION:-0.9.0-beta.1}"
BASE_URL="${SPARKLE_BASE_URL:?SPARKLE_BASE_URL is required, e.g. https://downloads.example.com/orange}"
DMG_PATH="${SPARKLE_DMG_PATH:-$ROOT_DIR/dist/${APP_NAME}-${VERSION}.dmg}"
OUTPUT_PATH="${SPARKLE_FEED_PATH:-$ROOT_DIR/dist/appcast.xml}"
PUB_DATE="$(date -u +"%a, %d %b %Y %H:%M:%S %z")"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "[sparkle] DMG not found: $DMG_PATH"
  exit 1
fi

FILE_NAME="$(basename "$DMG_PATH")"
FILE_SIZE="$(stat -f%z "$DMG_PATH")"
SIGNATURE="${SPARKLE_ED_SIGNATURE:-}"

cat > "$OUTPUT_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>${APP_NAME} Appcast</title>
    <link>${BASE_URL}</link>
    <description>${APP_NAME} beta updates</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <enclosure
        url="${BASE_URL}/${FILE_NAME}"
        sparkle:version="${VERSION}"
        sparkle:shortVersionString="${VERSION}"
        length="${FILE_SIZE}"
        type="application/octet-stream"
EOF

if [[ -n "$SIGNATURE" ]]; then
  cat >> "$OUTPUT_PATH" <<EOF
        sparkle:edSignature="${SIGNATURE}"
EOF
fi

cat >> "$OUTPUT_PATH" <<EOF
      />
    </item>
  </channel>
</rss>
EOF

echo "[sparkle] Appcast generated: $OUTPUT_PATH"
