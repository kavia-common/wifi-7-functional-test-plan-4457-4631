#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# idempotent venv
if [ ! -d ".venv" ]; then python3 -m venv .venv; fi
VENV_BIN="$WORKSPACE/.venv/bin"
# ensure pip
if [ -x "$VENV_BIN/python" ] && ! "$VENV_BIN/python" -m pip --version >/dev/null 2>&1; then
  "$VENV_BIN/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
fi
# pinned requirements
cat > "$WORKSPACE/requirements.txt" <<'REQ'
Flask==2.2.5
pytest==7.4.0
celery==5.3.1
REQ
# app
cat > "$WORKSPACE/app.py" <<'PY'
from flask import Flask, jsonify, request
app = Flask(__name__)
@app.route('/health')
def health():
    return jsonify(status='ok')
@app.route('/run-test', methods=['POST'])
def run_test():
    payload = request.get_json(silent=True) or {}
    return jsonify(received=payload), 202
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PY
# tasks
cat > "$WORKSPACE/tasks.py" <<'PY'
from celery import Celery
import os
broker = os.environ.get('CELERY_BROKER_URL','redis://localhost:6379/0')
cel = Celery('coredoc', broker=broker)
@cel.task
def noop(x):
    return x
PY
mkdir -p "$WORKSPACE/logs" "$WORKSPACE/data" "$WORKSPACE/docs"
# sqlite touch
sqlite3 "$WORKSPACE/data/artifacts.db" "VACUUM;" >/dev/null 2>&1 || true
# mkdocs
cat > "$WORKSPACE/mkdocs.yml" <<'MK'
site_name: CoreDocumentation&GovernanceHub
nav:
  - Home: index.md
MK
cat > "$WORKSPACE/docs/index.md" <<'MD'
# CoreDocumentation&GovernanceHub
Documentation placeholder.
MD
cat > "$WORKSPACE/.gitignore" <<'GI'
.venv/
__pycache__/
*.pyc
logs/
data/
flask.pid
celery.pid
GI
# activate helper
cat > "$WORKSPACE/activate_env.sh" <<'ACT'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${WORKSPACE}"
if [ -f "${WORKSPACE}/.env" ]; then set -a; . "${WORKSPACE}/.env"; set +a; fi
if [ -f "${WORKSPACE}/.venv/bin/activate" ]; then . "${WORKSPACE}/.venv/bin/activate"; fi
ACT
chmod +x "$WORKSPACE/activate_env.sh"
# start script
cat > "$WORKSPACE/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${WORKSPACE}"
cd "$WORKSPACE"
[ -f "${WORKSPACE}/activate_env.sh" ] && . "${WORKSPACE}/activate_env.sh"
export PYTHONPATH="$WORKSPACE":${PYTHONPATH:-}
LOG_DIR="$WORKSPACE/logs"
mkdir -p "$LOG_DIR"
FLASK_LOG="$LOG_DIR/flask.log"
CELERY_LOG="$LOG_DIR/celery.log"
if [ -f "$WORKSPACE/flask.pid" ]; then PID=$(cat "$WORKSPACE/flask.pid" 2>/dev/null||true); if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then echo "flask already running" && exit 0; else rm -f "$WORKSPACE/flask.pid" || true; fi; fi
if [ -f "$WORKSPACE/celery.pid" ]; then PID=$(cat "$WORKSPACE/celery.pid" 2>/dev/null||true); if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then echo "celery already running" && exit 0; else rm -f "$WORKSPACE/celery.pid" || true; fi; fi
export FLASK_APP=app.py
export FLASK_ENV=${FLASK_ENV:-development}
"$WORKSPACE/.venv/bin/python" -m flask run --host=0.0.0.0 --port=5000 --with-threads >>"$FLASK_LOG" 2>&1 &
echo $! > "$WORKSPACE/flask.pid"
CELERY_BIN="$(command -v celery || true)"
if [ -z "$CELERY_BIN" ]; then echo "celery_missing" >&2; exit 6; fi
cd "$WORKSPACE"
CELERY_BROKER_URL=${CELERY_BROKER_URL:-redis://localhost:6379/0} "$CELERY_BIN" -A tasks worker --loglevel=INFO --workdir="$WORKSPACE" >>"$CELERY_LOG" 2>&1 &
echo $! > "$WORKSPACE/celery.pid"
exit 0
SH
chmod +x "$WORKSPACE/start.sh" || true
echo "scaffolded"
