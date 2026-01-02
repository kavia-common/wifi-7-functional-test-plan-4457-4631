#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_PY="$WORKSPACE/.venv/bin/python"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/tests"
cat > "$WORKSPACE/tests/test_app.py" <<'PY'
import pytest
from app import app

def test_health():
    client = app.test_client()
    r = client.get('/health')
    assert r.status_code == 200
    assert r.get_json().get('status') == 'ok'
PY
# pytest.ini for stable discovery
cat > "$WORKSPACE/pytest.ini" <<'CFG'
[pytest]
addopts = -q
python_files = tests/test_*.py
CFG
# Run tests with venv python
if [ ! -x "$VENV_PY" ]; then
  echo "ERROR: virtualenv python not found at $VENV_PY" >&2
  exit 2
fi
"$VENV_PY" -m pytest
