#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# idempotent venv
if [ ! -d "$WORKSPACE/.venv" ]; then
  python3 -m venv "$WORKSPACE/.venv"
fi
VENV_PY="$WORKSPACE/.venv/bin/python"
# requirements
cat > "$WORKSPACE/requirements.txt" <<'REQ'
Flask>=2.0,<3.0
pytest>=7.0,<8.0
REQ
# app package
mkdir -p "$WORKSPACE/app"
cat > "$WORKSPACE/app/__init__.py" <<'PY'
import os
from flask import Flask, jsonify
from sqlite3 import connect

DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data.db'))

def create_app():
    app = Flask(__name__)
    @app.route('/health')
    def health():
        return jsonify(status='ok')
    @app.route('/dbinfo')
    def dbinfo():
        conn = connect(DB_PATH)
        cur = conn.cursor()
        cur.execute('CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)')
        conn.commit()
        conn.close()
        return jsonify(db='sqlite', file=DB_PATH)
    return app

app = create_app()
PY
# docs
mkdir -p "$WORKSPACE/docs"
cat > "$WORKSPACE/mkdocs.yml" <<'YML'
site_name: CoreDocumentation&GovernanceHub
nav:
  - Home: index.md
YML
cat > "$WORKSPACE/docs/index.md" <<'MD'
# CoreDocumentation&GovernanceHub
Minimal documentation scaffold.
MD
# start script (headless, uses venv python explicitly)
cat > "$WORKSPACE/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_PY="$WORKSPACE/.venv/bin/python"
cd "$WORKSPACE"
export FLASK_APP=app
mkdir -p "$WORKSPACE/logs"
# Launch in background and record PID and PGID for validation symmetry
( exec "$VENV_PY" -m flask run --host 0.0.0.0 --port 8000 > "$WORKSPACE/logs/start.log" 2>&1 ) &
CHILD=$!
PGID=$(ps -o pgid= "$CHILD" 2>/dev/null | tr -d ' ')
printf "%s\n" "$CHILD" > "$WORKSPACE/.server.pid"
printf "%s\n" "${PGID:-}" > "$WORKSPACE/.server.pgid"
# wait on child to keep behavior similar to foreground for CI systems
exec wait "$CHILD"
SH
chmod +x "$WORKSPACE/start.sh"
# ci runner
cat > "$WORKSPACE/ci_run.sh" <<'CI'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_PY="$WORKSPACE/.venv/bin/python"
cd "$WORKSPACE"
# run tests using venv python
"$VENV_PY" -m pytest -q || { echo 'pytest failed' >&2; exit 2; }
# build docs via mkdocs if available
if command -v mkdocs >/dev/null 2>&1; then
  mkdocs build -f "$WORKSPACE"/mkdocs.yml -d "$WORKSPACE"/site || { echo 'mkdocs build failed' >&2; exit 3; }
else
  echo 'mkdocs not found in PATH' >&2; exit 4
fi
CI
chmod +x "$WORKSPACE/ci_run.sh"
# housekeeping
cat > "$WORKSPACE/.gitignore" <<G
.venv/
__pycache__/
site/
data.db
G
mkdir -p "$WORKSPACE/logs"
echo "CoreDocumentation&GovernanceHub - scaffold" > "$WORKSPACE/README.md"
