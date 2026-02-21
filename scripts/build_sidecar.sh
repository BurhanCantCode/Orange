#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_DIR="$ROOT_DIR/agent"
VENV_DIR="$AGENT_DIR/.venv-packaging"

cd "$AGENT_DIR"

python3.13 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r "$AGENT_DIR/requirements.txt" pyinstaller

rm -rf "$AGENT_DIR/build" "$AGENT_DIR/dist/sidecar_server" "$AGENT_DIR/sidecar_server.spec"

pyinstaller \
  --noconfirm \
  --clean \
  --onedir \
  --name sidecar_server \
  --paths "$AGENT_DIR" \
  --collect-submodules app \
  --collect-submodules core \
  --collect-submodules macos_use_adapter \
  "$AGENT_DIR/packaging/sidecar_entry.py"

echo "[sidecar] Built artifact at $AGENT_DIR/dist/sidecar_server"
