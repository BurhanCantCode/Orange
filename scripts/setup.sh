#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

python3.13 -m venv "$ROOT_DIR/agent/.venv"
source "$ROOT_DIR/agent/.venv/bin/activate"
pip install -r "$ROOT_DIR/agent/requirements.txt"

echo "Agent environment ready."
