#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
# ensure venv exists (idempotent)
[ -x "$WS/.venv/bin/python" ] || python3 -m venv "$WS/.venv"
# ensure pip is upgraded in venv for reliable installs
"$WS/.venv/bin/python" -m pip --disable-pip-version-check install --upgrade pip >/dev/null 2>&1 || true
# install from requirements using absolute pip (idempotent)
"$WS/.venv/bin/pip" --disable-pip-version-check install --upgrade -r "$WS/requirements.txt"
# verify imports via absolute python
"$WS/.venv/bin/python" - <<'PY'
import sys
try:
    import flask, requests
except Exception as e:
    print('package import check failed:', e, file=sys.stderr)
    sys.exit(2)
print('pkgs_ok')
PY
# Show venv gunicorn location/version if installed there, else show system gunicorn info for diagnostics
if "$WS/.venv/bin/python" -c "import importlib.util,sys
spec = importlib.util.find_spec('gunicorn')
print('yes' if spec else 'no')" | grep -q yes; then
  # run venv-installed gunicorn version via python -m to avoid shell PATH ambiguity
  "$WS/.venv/bin/python" -m gunicorn --version || true
else
  if command -v gunicorn >/dev/null 2>&1; then
    # informational only; do not attempt to reinstall global gunicorn
    gunicorn --version || true
  fi
fi
