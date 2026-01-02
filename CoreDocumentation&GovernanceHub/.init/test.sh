#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "${WORKSPACE}"
VENV_PY="${WORKSPACE}/.venv/bin/python"
mkdir -p tests
TEST_FILE="${WORKSPACE}/tests/test_app_client.py"
if [ -f "${TEST_FILE}" ]; then
  mv "${TEST_FILE}" "${TEST_FILE}.bak_$(date +%s)"
fi
cat > "${TEST_FILE}" <<'PY'
import os
import pytest
# ensure COREDOC_ARTIFACTS is set before importing app
@pytest.fixture
def client(tmp_path):
    art = tmp_path / 'artifacts.json'
    os.environ['COREDOC_ARTIFACTS'] = str(art)
    from app import app
    app.testing = True
    with app.test_client() as c:
        yield c

def test_health(client):
    rv = client.get('/health')
    assert rv.status_code == 200
    assert rv.get_json().get('status') == 'ok'

def test_artifacts_store_and_retrieve(client):
    payload = {'k': 'v'}
    r = client.post('/artifacts', json=payload)
    assert r.status_code == 201
    r2 = client.get('/artifacts')
    assert isinstance(r2.get_json(), list)
PY

# run pytest via venv python when available
if [ -x "${VENV_PY}" ]; then
  "${VENV_PY}" -m pytest -q || { echo "ERROR: pytest failed" >&2; exit 2; }
else
  pytest -q || { echo "ERROR: pytest failed" >&2; exit 2; }
fi
