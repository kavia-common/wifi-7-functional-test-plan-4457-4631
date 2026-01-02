#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_DIR="${VENV_DIR:-/opt/venvs/coredoc_govhub}"
PY="$VENV_DIR/bin/python3"
[ -x "$PY" ] || PY="$VENV_DIR/bin/python"
PIP="$VENV_DIR/bin/pip"
REQS="$WORKSPACE/requirements.txt"
if [ ! -x "$PY" ] || [ ! -x "$PIP" ]; then echo "error: venv python/pip missing; run env-001" >&2; exit 2; fi
PIP_LOG=/tmp/coredoc_pip_install.log
install_reqs(){ "$PIP" install --no-cache-dir -r "$REQS" >"$PIP_LOG" 2>&1; }
# install only if flask not importable in venv
if ! "$PY" -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('flask') else 1)"; then
  if ! install_reqs; then
    sleep 1
    if ! install_reqs; then
      echo "error: pip install failed; see $PIP_LOG" >&2
      sed -n '1,200p' "$PIP_LOG" >&2 || true
      exit 3
    fi
  fi
fi
# optional pytest
if [ "${TEST:-false}" = "true" ]; then
  if ! "$PY" -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('pytest') else 1)"; then
    if ! "$PIP" install --no-cache-dir "pytest>=7.0,<8.0" >"$PIP_LOG" 2>&1; then
      sleep 1
      if ! "$PIP" install --no-cache-dir "pytest>=7.0,<8.0" >"$PIP_LOG" 2>&1; then
        echo "error: pytest install failed; see $PIP_LOG" >&2
        sed -n '1,200p' "$PIP_LOG" >&2 || true
        exit 4
      fi
    fi
  fi
fi
# final verify flask import
if ! "$PY" -c "import importlib; importlib.import_module('flask')"; then echo "error: flask import failed in venv" >&2; exit 5; fi
