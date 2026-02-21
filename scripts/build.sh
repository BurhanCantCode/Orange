#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR/apps/desktop"
swift build -c release

echo "Desktop binary built at apps/desktop/.build/release/OrangeApp"
