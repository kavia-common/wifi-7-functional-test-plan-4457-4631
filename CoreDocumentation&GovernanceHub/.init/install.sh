#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_PY="$WS/.venv/bin/python"
VENV_PIP="$WS/.venv/bin/pip"
# verify workspace exists
[ -d "$WS" ] || { echo "workspace missing: $WS" >&2; exit 2; }
# verify venv python exists
if [ ! -x "$VENV_PY" ]; then
  echo "venv python missing at $VENV_PY" >&2
  exit 4
fi
# upgrade packaging tools quietly
"$VENV_PY" -m pip install --upgrade pip setuptools wheel -q || { echo "failed to upgrade pip/setuptools/wheel" >&2; exit 6; }
# install requirements if file exists
if [ -f "$WS/requirements.txt" ]; then
  "$VENV_PIP" install -q -r "$WS/requirements.txt" || { echo "pip install requirements failed" >&2; exit 7; }
else
  echo "requirements.txt not found in workspace: $WS/requirements.txt" >&2
  exit 8
fi
# verify required packages: accept gunicorn or uvicorn; pytest required
"$VENV_PY" - <<'PY'
import importlib, sys
ok = True
try:
    importlib.import_module('pytest')
except Exception:
    print('missing pytest', file=sys.stderr); ok=False
# prefer gunicorn but allow uvicorn fallback
g = u = False
try:
    importlib.import_module('gunicorn')
    g = True
except Exception:
    pass
try:
    importlib.import_module('uvicorn')
    u = True
except Exception:
    pass
if not (g or u):
    print('neither gunicorn nor uvicorn found in venv; install gunicorn or uvicorn', file=sys.stderr); ok=False
if not ok:
    sys.exit(4)
print('deps_ok')
PY
# ensure venv-local binaries exist for pytest and preferred server
if [ -x "$WS/.venv/bin/pytest" ] || [ -x "$WS/.venv/bin/py.test" ]; then :; else echo "pytest binary missing in venv" >&2; exit 5; fi
if [ -x "$WS/.venv/bin/gunicorn" ]; then
  :
elif [ -x "$WS/.venv/bin/uvicorn" ]; then
  :
else
  echo "neither gunicorn nor uvicorn binary found in venv" >&2; exit 6
fi
# success
printf "install: OK\n"
