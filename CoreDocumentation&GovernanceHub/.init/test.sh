#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WS"
VENV="$WS/.venv"
# create pytest that uses Flask test_client
cat > "$WS/test_health.py" <<'PYT'
import app

def test_health():
    client = app.app.test_client()
    rv = client.get('/health')
    assert rv.status_code == 200
    j = rv.get_json()
    assert j.get('status') == 'ok'
PYT

# run pytest via venv
"$VENV/bin/pytest" -q || { echo "pytest failed" >&2; exit 7; }
