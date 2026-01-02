#!/usr/bin/env bash
set -euo pipefail
# Install step: upgrade pip and install pinned requirements into workspace venv non-interactively
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
VENV_PY="$WORKSPACE/.venv/bin/python"
LOG="$WORKSPACE/install.log"
# Ensure venv python exists
if [ ! -x "$VENV_PY" ]; then
  echo "venv python not present; create venv first" >&2
  exit 2
fi
# Upgrade pip using venv python; capture output
if ! "$VENV_PY" -m pip install --upgrade pip >"$LOG" 2>&1; then
  echo "pip upgrade failed; tailing $LOG" >&2
  tail -n 200 "$LOG" >&2 || true
  exit 3
fi
# Install requirements with one retry on failure
if ! "$VENV_PY" -m pip install -r requirements.txt >>"$LOG" 2>&1; then
  sleep 1
  if ! "$VENV_PY" -m pip install -r requirements.txt >>"$LOG" 2>&1; then
    echo "pip install failed after retry; tailing $LOG" >&2
    tail -n 200 "$LOG" >&2 || true
    exit 4
  fi
fi
# Verify pip is the venv pip
if ! "$VENV_PY" -m pip --version >/dev/null 2>&1; then
  echo "venv pip not functional" >&2
  exit 5
fi
# Validate packages are importable and print versions; exit 2 if missing
"$VENV_PY" - <<'PY'
import importlib, sys
missing = []
for pkg in ("flask","requests","pytest"):
    try:
        m = importlib.import_module(pkg)
        ver = getattr(m, '__version__', getattr(m, 'VERSION', 'unknown'))
        print(pkg, ver)
    except Exception as e:
        print('missing', pkg, e, file=sys.stderr)
        missing.append(pkg)
if missing:
    sys.exit(2)
print('deps_ok')
PY
