#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
# ensure venv exists
if [ ! -x "$WS/.venv/bin/python" ]; then
  python3 -m venv "$WS/.venv"
  "$WS/.venv/bin/python" -m pip --disable-pip-version-check install --upgrade pip >/dev/null
fi
# install pytest into venv (idempotent)
"$WS/.venv/bin/pip" --disable-pip-version-check install -q pytest >/dev/null
# create tests dir and minimal smoke test
mkdir -p "$WS/tests"
cat > "$WS/tests/test_health.py" <<'PY'
import os
from corehub import create_app

def test_health():
    # ensure isolation: use in-memory sqlite
    os.environ['DATABASE_URL'] = 'sqlite:///:memory:'
    app = create_app()
    client = app.test_client()
    rv = client.get('/health')
    assert rv.status_code == 200
    assert rv.get_json().get('status') == 'ok'
PY
# run pytest using absolute venv binary for reproducibility
"$WS/.venv/bin/pytest" -q --maxfail=1 "$WS/tests"
