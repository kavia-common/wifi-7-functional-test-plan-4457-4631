#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_PYTEST="$WS/.venv/bin/pytest"
cd "$WS"
# ensure tests dir exists
mkdir -p "$WS/tests"
# create a simple pytest test that uses in-memory DB to avoid side effects
cat >"$WS/tests/test_index.py" <<'PY'
import os
from app.main import app

def test_root():
    # use Flask test client
    c = app.test_client()
    r = c.get('/')
    assert r.status_code == 200
    # expect JSON {"status": "ok"} or similar
    j = r.get_json(silent=True)
    assert j is not None and j.get('status') == 'ok'
PY

# verify venv pytest exists
if [ ! -x "$VENV_PYTEST" ]; then
  echo "ERROR: pytest binary not found at $VENV_PYTEST. Ensure .venv exists and dependencies installed (run .init/install.sh)." >&2
  exit 2
fi
# run pytest using venv-local binary
"$VENV_PYTEST" -q "$WS/tests"
