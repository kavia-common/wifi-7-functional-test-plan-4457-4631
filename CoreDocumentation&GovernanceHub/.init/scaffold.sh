#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WS"
cd "$WS"
# minimal Flask app and requirements only if missing
cat > "$WS/requirements.txt" <<'PYREQ'
Flask
requests
pytest
PYREQ

if [ ! -f "$WS/app.py" ]; then
  cat > "$WS/app.py" <<'PY'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/')
def index():
    return "CoreDocumentation&GovernanceHub\n"

@app.route('/health')
def health():
    return jsonify(status='ok')

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8000)
PY
fi

# start helper (deterministic) if missing
cat > "$WS/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WS"
VENV="$WS/.venv"
LOG=/tmp/cdgh_app.log
PIDFILE="$WS/run.pid"
PORT=8000
HOST=127.0.0.1
if [ -f "$PIDFILE" ]; then
  if kill -0 "$(cat "$PIDFILE")" >/dev/null 2>&1; then
    exit 0
  else
    rm -f "$PIDFILE" || true
  fi
fi
setsid "$VENV/bin/python" -m flask run --host=$HOST --port=$PORT >"$LOG" 2>&1 &
PID=$!
echo "$PID" >"$PIDFILE"
SH
chmod +x "$WS/start.sh"

# minimal README hint
cat > "$WS/README.md" <<'MD'
Minimal Flask app for validation. Use the .init scripts to install, test, start and validate.
MD
