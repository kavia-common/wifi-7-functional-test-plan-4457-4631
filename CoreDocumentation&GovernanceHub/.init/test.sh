#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/tests"
# Create minimal pytest test for FastAPI health endpoint (idempotent)
if [ ! -f "$WORKSPACE/tests/test_health.py" ]; then
  cat > "$WORKSPACE/tests/test_health.py" <<'PY'
from fastapi.testclient import TestClient
from app.main import app

def test_health():
    client = TestClient(app)
    r = client.get('/health')
    assert r.status_code == 200
    assert r.json().get('status') == 'ok'
PY
fi
# Choose venv python if available to avoid environment mismatches
PYBIN="$WORKSPACE/.venv/bin/python"
LOGDIR="$WORKSPACE/tests"
PYTEST_LOG="$LOGDIR/pytest.log"
SUMMARY="$LOGDIR/test_summary.txt"
if [ -x "$PYBIN" ]; then
  "$PYBIN" -m pytest tests 2>&1 | tee "$PYTEST_LOG" || (echo "pytest failed, see $PYTEST_LOG" >&2; exit 6)
  "$PYBIN" - <<'PY' > "$SUMMARY"
import sys
print('pytest log: tests/pytest.log')
PY
else
  python3 -m pytest tests 2>&1 | tee "$PYTEST_LOG" || (echo "pytest failed, see $PYTEST_LOG" >&2; exit 6)
  python3 - <<'PY' > "$SUMMARY"
import sys
print('pytest log: tests/pytest.log')
PY
fi
