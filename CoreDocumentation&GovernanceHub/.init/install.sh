#!/usr/bin/env bash
set -euo pipefail
# dependencies step: upgrade packaging tools inside workspace venv and install pinned requirements
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
[ -f "${WORKSPACE}/activate_env.sh" ] && . "${WORKSPACE}/activate_env.sh"
VENV_PY="$WORKSPACE/.venv/bin/python"
if [ ! -x "$VENV_PY" ]; then
  echo ".venv missing or invalid" >&2
  exit 2
fi
mkdir -p "$WORKSPACE/logs"
PIP_LOG="$WORKSPACE/logs/pip_install.log"
# ensure requirements.txt exists
if [ ! -f "$WORKSPACE/requirements.txt" ]; then
  echo "requirements.txt not found in workspace" >&2
  exit 6
fi
# Upgrade packaging tools and install requirements (append outputs to log)
# First attempt normal install, on failure retry with --no-cache-dir
"$VENV_PY" -m pip install --upgrade pip setuptools wheel >>"$PIP_LOG" 2>&1 || { echo "pip_upgrade_failed" >&2; tail -n 200 "$PIP_LOG" >&2; exit 3; }
"$VENV_PY" -m pip install -r requirements.txt >>"$PIP_LOG" 2>&1 || {
  "${VENV_PY}" -m pip install --no-cache-dir -r requirements.txt >>"$PIP_LOG" 2>&1 || { echo "pip_install_failed" >&2; tail -n 200 "$PIP_LOG" >&2; exit 4; }
}
# Record exact installed versions
"$VENV_PY" -m pip freeze > "$WORKSPACE/requirements.lock"
# Append runtime summary to pip log for evidence (python and key packages)
"$VENV_PY" -c "import sys
print('python', sys.version.split()[0])
for pkg in ('flask','pytest','celery'):
    try:
        m = __import__(pkg)
        print(pkg, getattr(m, '__version__', 'unknown'))
    except Exception:
        print(pkg, 'not importable')
" >>"$PIP_LOG" 2>&1 || true
# Verify celery binary availability (prefer venv)
VENV_CELERY="$WORKSPACE/.venv/bin/celery"
if [ -x "$VENV_CELERY" ]; then
  echo "celery_in_venv" >>"$PIP_LOG"
else
  if command -v celery >/dev/null 2>&1; then
    echo "celery_global_used" >>"$PIP_LOG"
  else
    echo "celery_missing" >>"$PIP_LOG" 2>&1
    tail -n 200 "$PIP_LOG" 2>/dev/null || true
    exit 5
  fi
fi
echo "deps_ok"
