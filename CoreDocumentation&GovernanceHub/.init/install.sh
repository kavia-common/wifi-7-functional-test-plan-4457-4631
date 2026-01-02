#!/usr/bin/env bash
set -euo pipefail
# dependencies - create venv, install pinned Python deps with explicit venv tooling
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
VENV="$WORKSPACE/.venv"
PY="$VENV/bin/python"
PIP="$VENV/bin/pip"
# create venv if missing (idempotent)
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV" || { echo "venv creation failed" >&2; VENV_ERR=1; }
fi
# ensure venv pip/python references
if [ -x "$PY" ]; then
  # upgrade pip/setuptools/wheel inside venv, ignore non-fatal failures
  "$PY" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  PKG_PIP="$PIP"
  PKG_PY="$PY"
else
  echo "venv not available; will attempt user installs" >&2
  PKG_PIP="python3 -m pip"
  PKG_PY="python3"
fi
# install requirements into venv (or --user fallback)
INSTALL_ERR=0
if [ -f "requirements.txt" ]; then
  if [ -x "$PIP" ]; then
    "$PIP" install --no-cache-dir -r requirements.txt || INSTALL_ERR=1
  else
    python3 -m pip install --user --no-cache-dir -r requirements.txt || INSTALL_ERR=1
  fi
fi
if [ "${INSTALL_ERR-0}" = "1" ]; then
  echo "install failed in venv, attempting --user fallback" >&2
  python3 -m pip install --user --no-cache-dir -r requirements.txt || { echo "pip install failed in venv and --user; aborting" >&2; exit 4; }
fi
# record venv package versions using pip list --format=json
if [ -x "$PIP" ]; then
  "$PIP" list --format=json > "$WORKSPACE/venv_packages.json" || true
else
  python3 -m pip list --format=json > "$WORKSPACE/venv_packages.json" || true
fi
# record tool versions (system and venv)
{
  echo "system_python: $(python3 --version 2>&1 || true)"
  echo "system_pip: $(python3 -m pip --version 2>&1 || true)"
  if [ -x "$PY" ]; then
    echo "venv_python: $($PY --version 2>&1 || true)"
    echo "venv_pip: $($PY -m pip --version 2>&1 || true)"
  fi
} > "$WORKSPACE/tool_versions.txt"

# Exit codes: 0 success, 4 pip install failed both venv and --user
