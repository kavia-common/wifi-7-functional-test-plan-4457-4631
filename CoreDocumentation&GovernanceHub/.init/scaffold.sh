#!/usr/bin/env bash
set -euo pipefail
WORKDIR="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WORKDIR" && cd "$WORKDIR"
# app.py (idempotent)
if [ ! -f "$WORKDIR/app.py" ]; then
  cat > "$WORKDIR/app.py" <<'PY'
from flask import Flask, jsonify, request
import sqlite3, os
DB = os.path.join(os.path.dirname(__file__), 'data.db')
app = Flask(__name__)

def get_conn():
    # timeout reduces "database is locked" races
    conn = sqlite3.connect(DB, timeout=5)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_conn()
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute('CREATE TABLE IF NOT EXISTS docs (id INTEGER PRIMARY KEY, title TEXT, body TEXT)')
    conn.commit(); conn.close()

@app.route('/')
def index():
    return jsonify({'status':'ok','service':'CoreDocumentation&GovernanceHub'})

@app.route('/docs', methods=['GET','POST'])
def docs():
    init_db()
    conn = get_conn()
    if request.method == 'POST':
        data = request.get_json() or {}
        title = data.get('title','')
        body = data.get('body','')
        cur = conn.cursor(); cur.execute('INSERT INTO docs (title,body) VALUES (?,?)',(title,body)); conn.commit(); nid = cur.lastrowid; conn.close()
        return jsonify({'id':nid}), 201
    rows = conn.execute('SELECT id,title,body FROM docs').fetchall(); conn.close()
    return jsonify([{'id':r['id'],'title':r['title'],'body':r['body']} for r in rows])

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000)
PY
fi
# requirements.txt (with guidance)
if [ ! -f "$WORKDIR/requirements.txt" ]; then
  cat > "$WORKDIR/requirements.txt" <<'REQ'
# Pin versions in CI for reproducibility; examples:
# Flask>=2.0,<3.0
# pytest>=7.0
Flask
pytest
requests
REQ
fi
# run.sh written idempotently; sets FLASK_* at runtime
if [ ! -f "$WORKDIR/run.sh" ]; then
  cat > "$WORKDIR/run.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# source local venv if present
[ -f "$SCRIPT_DIR/activate_project.sh" ] && . "$SCRIPT_DIR/activate_project.sh"
export FLASK_APP=app.py
export FLASK_ENV=development
exec python -m flask run --host=0.0.0.0 --port=5000
SH
  chmod 755 "$WORKDIR/run.sh"
fi
# .gitignore
if [ ! -f "$WORKDIR/.gitignore" ]; then
  cat > "$WORKDIR/.gitignore" <<'GI'
.venv/
__pycache__/
*.pyc
data.db
GI
fi
# README.md (usage/test docs)
if [ ! -f "$WORKDIR/README.md" ]; then
  cat > "$WORKDIR/README.md" <<'MD'
# CoreDocumentation&GovernanceHub

Usage:
  source ./activate_project.sh
  ./run.sh   # runs flask dev server (development only)

Run tests (non-interactive):
  ./.venv/bin/python -m pytest -q tests

Data file: data.db in project workspace
MD
fi
# ensure DB file exists and has safe perms
touch "$WORKDIR/data.db" 2>/dev/null || true
chmod 660 "$WORKDIR/data.db" 2>/dev/null || true
chown $(id -u):$(id -g) "$WORKDIR/data.db" 2>/dev/null || true

# Create a lightweight activate helper for the workspace venv (if .venv exists later)
if [ ! -f "$WORKDIR/activate_project.sh" ]; then
  cat > "$WORKDIR/activate_project.sh" <<'AV'
# workspace-local venv activation helper (does NOT export FLASK_* vars)
# Usage: . ./activate_project.sh
if [ -f "./.venv/bin/activate" ]; then
  . "./.venv/bin/activate"
fi
AV
  chmod 644 "$WORKDIR/activate_project.sh"
fi

echo "scaffold: done"
