#!/usr/bin/env bash
set -euo pipefail
WORKDIR="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
SAFE_WORKDIR=${SAFE_WORKDIR:-"$WORKDIR"}
cd "$WORKDIR"
VENV_PY="$SAFE_WORKDIR/.venv/bin/python"
if [ ! -x "$VENV_PY" ]; then echo "ERROR: venv python not found at $VENV_PY" >&2; exit 2; fi
# ensure pip bootstrapped
"$VENV_PY" -m ensurepip --upgrade >/dev/null 2>&1 || true
# upgrade packaging tools via venv python -m pip
"$VENV_PY" -m pip install --upgrade pip setuptools wheel >/dev/null
# install requirements using venv python -m pip (bypass .venv/bin/pip wrapper)
if [ -f "$WORKDIR/requirements.txt" ]; then
  "$VENV_PY" -m pip install -r "$WORKDIR/requirements.txt" >/dev/null || { echo "ERROR: pip install failed" >&2; "$VENV_PY" -m pip --version; exit 6; }
fi
# write freeze and pip version
"$VENV_PY" -m pip freeze > "$WORKDIR/venv-pip-freeze.txt"
"$VENV_PY" -m pip --version > "$WORKDIR/venv-pip-version.txt"
# print selected package versions for operator visibility
"$VENV_PY" - <<'PY'
import importlib,sys
for n in ('flask','pytest','requests'):
    try:
        m = importlib.import_module(n)
        v = getattr(m, '__version__', 'unknown')
        print(f"VENV_{n.upper()}={v}")
    except Exception:
        print(f"VENV_{n.upper()}=not-installed")
PY
