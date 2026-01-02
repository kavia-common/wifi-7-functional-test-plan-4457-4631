#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# marker for workspace discovery
sudo install -m 0644 /dev/null /etc/profile.d/core_doc_gov_ws.sh || true
sudo bash -c "cat > /etc/profile.d/core_doc_gov_ws.sh <<'EOF'
export CORE_DOC_GOV_WS='"$WORKSPACE"'
EOF"
# activate helper
cat > activate.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$DIR/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$DIR/.venv/bin/activate"
else
  echo "No .venv found in $DIR; create with: python3 -m venv .venv" >&2
fi
EOF
chmod +x activate.sh
# create venv if missing
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
VENV_PY="$WORKSPACE/.venv/bin/python"
# pinned requirements
cat > requirements.txt <<'EOF'
flask==2.3.2
requests==2.31.0
pytest==7.4.2
EOF
# minimal Flask app with sqlite-backed init and health route
cat > app.py <<'EOF'
from flask import Flask, jsonify
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), 'data.db')

def init_db():
    if not os.path.exists(DB_PATH):
        conn = sqlite3.connect(DB_PATH)
        conn.execute('CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)')
        conn.commit()
        conn.close()

app = Flask(__name__)
init_db()

@app.route('/')
def index():
    return jsonify({"message":"CoreDocumentation&GovernanceHub running"})

@app.route('/health')
def health():
    return jsonify({"status":"ok"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF
# start.sh - foreground
cat > start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PY="$DIR/.venv/bin/python"
if [ -x "$VENV_PY" ]; then
  exec "$VENV_PY" "$DIR/app.py"
else
  exec python3 "$DIR/app.py"
fi
EOF
chmod +x start.sh
# run-bg.sh - background starter with atomic pid write and readiness check
cat > run-bg.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$DIR/.devserver.log"
PIDFILE="$DIR/.devserver.pid"
PORT=5000
TIMEOUT=${DEV_SERVER_TIMEOUT:-30}
# If pidfile exists and process alive, verify and exit
if [ -f "$PIDFILE" ]; then
  pid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
    if ps -p "$pid" -o comm= | grep -i -E 'python|python3' >/dev/null 2>&1; then
      exit 0
    fi
  fi
  rm -f "$PIDFILE" || true
fi
: >"$LOG"
# Activate venv if present
if [ -f "$DIR/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$DIR/.venv/bin/activate"
fi
# Start server directly and capture PID
if [ -x "$DIR/.venv/bin/python" ]; then
  "$DIR/.venv/bin/python" "$DIR/app.py" >>"$LOG" 2>&1 &
else
  python3 "$DIR/app.py" >>"$LOG" 2>&1 &
fi
bgpid=$!
# Validate bgpid is a python process; fallback to socket/pgrep detection
if ! ps -p "$bgpid" -o comm= | grep -i -E 'python|python3' >/dev/null 2>&1; then
  pid=""
  end=$((SECONDS+TIMEOUT))
  while [ $SECONDS -lt $end ]; do
    if command -v ss >/dev/null 2>&1; then
      pid=$(ss -ltnp 2>/dev/null | awk -v port=":$PORT" '$4 ~ port {gsub(/.*pid=/,"",$6); gsub(/,.*$/,"",$6); print $6}') || true
    fi
    if [ -z "$pid" ] && command -v pgrep >/dev/null 2>&1; then
      pid=$(pgrep -f "python .*app.py|flask" || true)
    fi
    if [ -n "$pid" ]; then break; fi
    sleep 1
  done
  if [ -z "$pid" ]; then
    echo "failed to detect server process; see $LOG" >&2
    exit 2
  fi
  bgpid=$pid
fi
# Atomic pid write
tmp="$PIDFILE.tmp"
echo "$bgpid" >"$tmp" && mv -f "$tmp" "$PIDFILE"
# Wait for /health
end=$((SECONDS+TIMEOUT))
while [ $SECONDS -lt $end ]; do
  if curl -sS --fail http://127.0.0.1:$PORT/health >/dev/null 2>&1; then
    exit 0
  fi
  sleep 1
done
# timeout
echo "server failed to become ready; tailing log:" >&2
tail -n 200 "$LOG" || true
exit 3
EOF
chmod +x run-bg.sh
# README and .gitignore
cat > README.md <<'EOF'
CoreDocumentation&GovernanceHub

Use ./start.sh for foreground dev server (interactive). Use ./run-bg.sh to start backgrounded server with logs in .devserver.log. Activate venv with: source .venv/bin/activate or use ./activate.sh.
EOF
cat > .gitignore <<'EOF'
data.db
.devserver.log
.devserver.pid
.venv/
EOF
