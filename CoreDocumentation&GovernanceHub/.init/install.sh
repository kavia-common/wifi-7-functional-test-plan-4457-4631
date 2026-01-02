#!/usr/bin/env bash
set -euo pipefail
# Install Python deps into workspace venv and validate isolation (robust)
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
VENV_PY="$WORKSPACE/.venv/bin/python"
[ -x "$VENV_PY" ] || { echo "ERROR: venv python not found: $VENV_PY" >&2; exit 12; }
# Try upgrading pip inside venv (retries, quiet). Continue if fails.
set +e
RETRIES=2; COUNT=0; LAST_ERR=0
while [ $COUNT -le $RETRIES ]; do
  "$VENV_PY" -m pip --disable-pip-version-check install --no-input --upgrade pip -q && LAST_ERR=0 && break || LAST_ERR=$?
  COUNT=$((COUNT+1))
  sleep 1
done
set -e
if [ $LAST_ERR -ne 0 ]; then echo "WARNING: pip upgrade failed (rc=$LAST_ERR), continuing with existing pip" >&2; fi
# Install requirements into venv; capture pip log for debugging on failure
set +e
"$VENV_PY" -m pip --disable-pip-version-check install --no-input -r requirements.txt > "$WORKSPACE/pip_install.log" 2>&1
RC=$?
set -e
if [ $RC -ne 0 ]; then echo "ERROR: pip install failed; tail pip_install.log:" >&2; tail -n 200 "$WORKSPACE/pip_install.log" >&2 || true; exit 13; fi
# Validate venv isolation by comparing realpaths
ACTUAL=$("$VENV_PY" -c 'import sys,os; print(os.path.realpath(sys.executable))')
EXPECT=$(python3 - <<PY
import os
print(os.path.realpath("$VENV_PY"))
PY
)
if [ "$ACTUAL" != "$EXPECT" ]; then
  echo "ERROR: venv isolation check failed: sys.executable=$ACTUAL expected=$EXPECT" >&2
  exit 14
fi
# Print brief evidence of successful install
"$VENV_PY" -c "import flask,pytest,requests,sys; print('executable',sys.executable); print('flask',getattr(flask,'__version__',None)); print('pytest',getattr(pytest,'__version__',None)); print('requests',getattr(requests,'__version__',None))"
