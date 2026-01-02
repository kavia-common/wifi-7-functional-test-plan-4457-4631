#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
[ -f "${WORKSPACE}/activate_env.sh" ] && . "${WORKSPACE}/activate_env.sh"
VENV_PY="$WORKSPACE/.venv/bin/python"
# create venv if missing
if [ ! -x "$VENV_PY" ]; then
  python3 -m venv "$WORKSPACE/.venv"
  "$WORKSPACE/.venv/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
fi
VENV_PY="$WORKSPACE/.venv/bin/python"
[ -x "$VENV_PY" ] || { echo ".venv missing" >&2; exit 2; }
# Compile bytecode
"$VENV_PY" -m compileall -q "$WORKSPACE" || true
# Validate requirements.lock exists
if [ ! -f "$WORKSPACE/requirements.lock" ]; then echo "requirements.lock missing" >&2; exit 3; fi
# Compare top-level packages: ensure each package in requirements.txt appears in requirements.lock
if [ -f "$WORKSPACE/requirements.txt" ]; then
  cut -d'=' -f1 "$WORKSPACE/requirements.txt" | while read -r pkg; do
    if [ -n "$pkg" ]; then
      if ! grep -i "^$pkg" "$WORKSPACE/requirements.lock" >/dev/null 2>&1; then
        echo "package $pkg not found in requirements.lock" >&2
        exit 4
      fi
    fi
  done
fi
echo "build_ok"
