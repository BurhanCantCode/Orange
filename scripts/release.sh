#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  APPLE_DEVELOPER_ID_APPLICATION
  SPARKLE_BASE_URL
)

for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "[release] Missing required env var: $v"
    exit 1
  fi
done

if [[ -z "${APPLE_NOTARY_PROFILE:-}" ]]; then
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    echo "[release] Missing notarization credentials. Set APPLE_NOTARY_PROFILE or APPLE_ID/APPLE_TEAM_ID/APPLE_APP_SPECIFIC_PASSWORD."
    exit 1
  fi
fi

"$(dirname "$0")/build.sh"
"$(dirname "$0")/notarize.sh"
"$(dirname "$0")/generate_sparkle_feed.sh"

echo "Release pipeline complete."
