#!/usr/bin/env bash
set -euo pipefail
# Create minimal Flask scaffold using authoritative workspace path
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
ARTIFACTS_DIR="$WORKSPACE/artifacts"
mkdir -p "$WORKSPACE/app" "$WORKSPACE/tests" "$ARTIFACTS_DIR" "$WORKSPACE/docs"
cat > "$WORKSPACE/app/__init__.py" <<'PY'
from flask import Flask, request, jsonify
import os, json, time
app = Flask(__name__)
ARTIFACTS_DIR = os.environ.get('ARTIFACTS_DIR') or os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'artifacts'))
os.makedirs(ARTIFACTS_DIR, exist_ok=True)

@app.get('/')
def index():
    return jsonify({'status': 'ok', 'service': 'CoreDocumentation&GovernanceHub'})

@app.post('/results')
def post_results():
    data = request.get_json(silent=True) or {}
    fname = os.path.join(ARTIFACTS_DIR, f"result_{int(time.time())}.json")
    with open(fname, 'w') as f:
        json.dump(data, f)
    return jsonify({'stored': fname}), 201
PY

cat > "$WORKSPACE/app/wsgi.py" <<'PY'
from app import app
import os
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', '5000')), debug=(os.environ.get('FLASK_DEBUG','0')=='1'))
PY

cat > "$WORKSPACE/requirements.txt" <<'TXT'
Flask>=2.0,<3.0
TXT

cat > "$WORKSPACE/run-dev.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_DIR="${VENV_DIR:-/opt/venvs/coredoc_govhub}"
PY="$VENV_DIR/bin/python3"
[ -x "$PY" ] || PY="$VENV_DIR/bin/python"
export ARTIFACTS_DIR="$WORKSPACE/artifacts"
export FLASK_DEBUG=${FLASK_DEBUG:-0}
export PORT=${PORT:-5000}
"$PY" "$WORKSPACE/app/wsgi.py"
SH
chmod +x "$WORKSPACE/run-dev.sh"

cat > "$WORKSPACE/run-uvicorn.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_DIR="${VENV_DIR:-/opt/venvs/coredoc_govhub}"
PY="$VENV_DIR/bin/python3"
[ -x "$PY" ] || PY="$VENV_DIR/bin/python"
# If an ASGI app exists at app.async_api:app, this will run it; uvicorn typically preinstalled
"$PY" -m uvicorn app.async_api:app --host 0.0.0.0 --port 8000
SH
chmod +x "$WORKSPACE/run-uvicorn.sh"

cat > "$WORKSPACE/tests/test_app.py" <<'PYT'
from app import app

def test_index():
    client = app.test_client()
    resp = client.get('/')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data.get('status') == 'ok'
PYT

cat > "$WORKSPACE/docs/conf.py" <<'PY'
project = 'CoreDocumentation&GovernanceHub'
extensions = []
master_doc = 'index'
PY
cat > "$WORKSPACE/docs/index.rst" <<'RST'
CoreDocumentation&GovernanceHub
=============================

.. toctree::
   
RST

cat > "$WORKSPACE/.env.example" <<'ENV'
# ARTIFACTS_DIR - where test results and artifacts are stored (absolute path)
ARTIFACTS_DIR="$ARTIFACTS_DIR"
# FLASK_DEBUG - 0 or 1
FLASK_DEBUG=0
# PORT - service port
PORT=5000
# Optional: override VENV_DIR to point to a custom sanitized venv
# VENV_DIR=/opt/venvs/coredoc_govhub
ENV

# initialize git if absent
if [ ! -d ".git" ]; then git init -q || true; git add -A >/dev/null 2>&1 || true; git commit -m "scaffold: minimal project" -q || true; fi
