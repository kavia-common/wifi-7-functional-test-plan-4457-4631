#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_PY="$WORKSPACE/.venv/bin/python"
cd "$WORKSPACE"
if [ ! -x "$VENV_PY" ]; then
  echo "venv python missing" >&2
  exit 10
fi
mkdir -p "$WORKSPACE/logs"
PIPLOG="$WORKSPACE/logs/pip_install.log"
# Upgrade pip and install requirements; capture logs on failure (keep normal run concise)
# Use -q for concise output; redirect stdout/stderr to PIPLOG and on failure print tail for debugging
"$VENV_PY" -m pip install -q --upgrade pip >"$PIPLOG" 2>&1 || { echo 'pip upgrade failed, last logs:' >&2; tail -n 200 "$PIPLOG" >&2; exit 11; }
"$VENV_PY" -m pip install -q -r "$WORKSPACE/requirements.txt" >"$PIPLOG" 2>&1 || { echo 'pip install failed, last logs:' >&2; tail -n 200 "$PIPLOG" >&2; exit 12; }
# Validate using venv interpreter
"$VENV_PY" -c "import importlib, sys
print('venv_python', sys.executable)
for pkg in ('flask','pytest'):
    try:
        m = importlib.import_module(pkg)
        print(pkg, getattr(m, '__version__', 'unknown'))
    except Exception as e:
        print(pkg, 'import_failed:', e)
        sys.exit(13)
"
