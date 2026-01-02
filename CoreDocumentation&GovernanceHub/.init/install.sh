#!/usr/bin/env bash
set -euo pipefail

# Activate venv, upgrade pip tooling, install pinned packages with no-cache and retries
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_ACTIVATE_PATH="${WORKSPACE}/.venv/bin/activate"
VENV_PY="${WORKSPACE}/.venv/bin/python"
cd "${WORKSPACE}"

if [ -f "${VENV_ACTIVATE_PATH}" ]; then
  # shellcheck disable=SC1091
  source "${VENV_ACTIVATE_PATH}"
else
  echo "ERROR: venv activate not found at ${VENV_ACTIVATE_PATH}" >&2
  exit 2
fi

# ensure venv python exists and pip is available via venv python
if [ -x "${VENV_PY}" ]; then
  "${VENV_PY}" -m pip --version >/dev/null
else
  echo "ERROR: venv python not found at ${VENV_PY}" >&2
  exit 3
fi

# upgrade packaging tools using venv python
"${VENV_PY}" -m pip install --upgrade pip setuptools wheel --no-cache-dir --disable-pip-version-check >/dev/null || { echo "ERROR: pip upgrade failed" >&2; exit 4; }

# install pinned requirements with retries and no cache
RETRIES=3
COUNT=0
until [ $COUNT -ge $RETRIES ]; do
  "${VENV_PY}" -m pip install -r requirements.txt --no-cache-dir --disable-pip-version-check --prefer-binary && break
  COUNT=$((COUNT+1))
  echo "pip install failed, retry $COUNT/$RETRIES" >&2
  sleep 2
done
if [ $COUNT -ge $RETRIES ]; then
  echo "ERROR: pip install failed after $RETRIES attempts" >&2
  exit 5
fi

# print installed package versions for verification (non-fatal)
"${VENV_PY}" -m pip show flask pytest requests || true

# verify imports using venv python; fail if any import fails
"${VENV_PY}" - <<'PY' >/dev/null 2>&1 || { echo "ERROR: required packages not importable in venv" >&2; exit 6; }
import importlib
import sys
failed = False
for p in ('flask','pytest','requests'):
    try:
        importlib.import_module(p)
    except Exception as e:
        sys.stderr.write(f'IMPORT_FAIL {p} {e}\n')
        failed = True
if failed:
    raise SystemExit(1)
PY

# success
exit 0
