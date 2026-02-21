#!/usr/bin/env bash
set -euo pipefail

"$(dirname "$0")/build.sh"
"$(dirname "$0")/notarize.sh"
"$(dirname "$0")/generate_sparkle_feed.sh"

echo "Release pipeline complete."
