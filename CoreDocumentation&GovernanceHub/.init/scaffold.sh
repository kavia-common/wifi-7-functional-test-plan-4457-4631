#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WS" && cd "$WS"
# create venv if missing
if [ ! -d "$WS/.venv" ]; then
  python3 -m venv "$WS/.venv"
  # upgrade pip quietly
  "$WS/.venv/bin/python" -m pip install --upgrade pip --quiet >/dev/null
fi
# write env.sh idempotently with restrictive perms
cat > "$WS/env.sh" <<'ENV'
# workspace-scoped env (single-quoted values to preserve special chars)
FLASK_ENV='development'
DATABASE_URL='sqlite:///data.db'
ENV
chmod 600 "$WS/env.sh"
# requirements with pinned compatible ranges
cat > "$WS/requirements.txt" <<'REQ'
Flask>=2.2,<3
gunicorn>=20,<21
requests
REQ
# create package dir
mkdir -p "$WS/corehub"
# write app factory idempotently
if [ ! -f "$WS/corehub/__init__.py" ]; then
cat > "$WS/corehub/__init__.py" <<'PY'
from flask import Flask, jsonify
import sqlite3
import os
from urllib.parse import urlparse, unquote

def get_db(path):
    conn = sqlite3.connect(path, check_same_thread=False)
    return conn


def _normalize_sqlite_path(url):
    """
    Normalize sqlite URL forms:
    - sqlite:///relative/path.db  -> relative path '/relative/path.db' from urlparse, treat as relative
    - sqlite:////absolute/path.db -> urlparse.path == '//absolute/path.db' -> normalize to '/absolute/path.db'
    Also handle percent-encoded characters.
    Returns a filesystem path (relative or absolute) or None if not sqlite.
    """
    if not url:
        return None
    u = urlparse(url)
    if u.scheme != 'sqlite':
        return None
    p = u.path or ''
    # urlparse yields '//absolute/path' for sqlite:////absolute
    if p.startswith('//'):
        # collapse to single leading slash for absolute path
        p = '/' + p.lstrip('/')
    # remove leading single slash for relative paths of form sqlite:///relative.db -> '/relative.db'
    # but keep as relative by stripping one leading slash if there are exactly one leading slash and no host
    # Decide: treat leading single slash as relative path (strip leading slash)
    if p.startswith('/') and not p.startswith('//'):
        # Convert '/relative/path' -> 'relative/path' to preserve relative semantics
        candidate = p[1:]
        # If candidate looks absolute (starts with mount like C:/) leave it; on unix keep as relative
        p = candidate
    # percent-decode
    p = unquote(p)
    return p


def create_app():
    app = Flask(__name__)
    db_url = os.environ.get('DATABASE_URL')
    db_file = _normalize_sqlite_path(db_url) if db_url else None
    if not db_file:
        db_file = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data.db'))
    else:
        # convert relative db_file to absolute path based on workspace root (parent of package)
        if not os.path.isabs(db_file):
            db_file = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', db_file))
    app.config['DATABASE'] = db_file

    @app.route('/health')
    def health():
        return jsonify(status='ok')

    @app.route('/meta')
    def meta():
        conn = get_db(app.config['DATABASE'])
        cur = conn.cursor()
        cur.execute('CREATE TABLE IF NOT EXISTS plans(id INTEGER PRIMARY KEY, name TEXT)')
        conn.commit()
        conn.close()
        return jsonify(plans=0)

    return app
PY
fi
# create start.sh (overwrite to ensure expected behavior)
cat > "$WS/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WS_DIR="$(cd "$(dirname "$0")" && pwd)"
# source workspace env to get DATABASE_URL and FLASK_ENV
[ -f "$WS_DIR/env.sh" ] && . "$WS_DIR/env.sh"
# source venv activate if present (activate is a file)
if [ -f "$WS_DIR/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  . "$WS_DIR/.venv/bin/activate"
fi
# prefer running gunicorn via venv python to ensure venv packages used
if [ -x "$WS_DIR/.venv/bin/python" ]; then
  PY="$WS_DIR/.venv/bin/python"
else
  PY="$(command -v python3 || true)"
fi
if [ -z "$PY" ]; then
  echo 'python runtime not found' >&2
  exit 4
fi
PIDFILE="$WS_DIR/gunicorn.pid"
# exec gunicorn via python -m to avoid relying on script exec bits
exec "$PY" -m gunicorn -w 2 -b 127.0.0.1:8000 "corehub:create_app()" --pid "$PIDFILE"
SH
chmod +x "$WS/start.sh"
# ensure data file exists
[ -f "$WS/data.db" ] || touch "$WS/data.db"
# ensure package is importable (empty __init__py already created)
[ -f "$WS/corehub/__init__.py" ] || touch "$WS/corehub/__init__.py"
