#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# Ensure python3 exists
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 2; }
# Create venv if missing
if [ ! -d "$WORKSPACE/.venv" ]; then
  python3 -m venv "$WORKSPACE/.venv"
fi
VENV_PY="$WORKSPACE/.venv/bin/python"
# Ensure venv pip exists
$VENV_PY -m pip --version >/dev/null 2>&1 || { $VENV_PY -m ensurepip --upgrade >/dev/null 2>&1 || { echo "ERROR: venv pip missing" >&2; exit 11; } }
# Minimal Flask app
cat > "$WORKSPACE/app.py" <<'PY'
from flask import Flask, jsonify
import os
app = Flask(__name__)
@app.route('/')
def index():
    return jsonify({"status":"ok","env": os.getenv('APP_ENV','dev')})
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('APP_PORT', '5000')))
PY
# Example project .env
cat > "$WORKSPACE/.env" <<'ENV'
APP_ENV=development
APP_PORT=5000
FLASK_APP=app.py
ENV
# requirements (pinned minimal dev deps)
cat > "$WORKSPACE/requirements.txt" <<'REQ'
Flask==2.3.4
pytest==7.4.0
requests==2.31.0
uvicorn==0.22.0
REQ
# start.sh: robust loader for .env that safely preserves single quotes
cat > "$WORKSPACE/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
ENVFILE="$WORKDIR/.env"
if [ -f "$ENVFILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    # strip inline comments
    line="${line%%#*}"
    # skip empty/whitespace
    case "$line" in
      ""|[[:space:]]*) continue;;
    esac
    if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      key=${line%%=*}
      val=${line#*=}
      # Preserve value verbatim, including single quotes and spaces
      # Use printf -v to avoid shell word-splitting and dangerous eval
      printf -v _val '%s' "$val"
      export "$key"="$_val"
    fi
  done < "$ENVFILE"
fi
exec "$WORKDIR/.venv/bin/python" "$WORKDIR/app.py"
SH
chmod +x "$WORKSPACE/start.sh"
# tests placeholder
mkdir -p "$WORKSPACE/tests" && [ -f "$WORKSPACE/tests/__init__.py" ] || touch "$WORKSPACE/tests/__init__.py"
# .gitignore
cat > "$WORKSPACE/.gitignore" <<'GI'
.venv
__pycache__
*.pyc
.env
*.sqlite3
server.log
validation_body.tmp
GI
# docs skeleton for mkdocs/sphinx verification
mkdir -p "$WORKSPACE/docs"
printf 'site_name: CoreDocumentation&GovernanceHub\n' > "$WORKSPACE/docs/mkdocs.yml"
# placeholder sqlite DB file
: > "$WORKSPACE/app.sqlite3"
# Ensure ownership and permissions are reasonable (non-root user typically in container)
chmod 644 "$WORKSPACE/app.sqlite3" || true
# Final validation: list created items succinctly
printf "Scaffolded: %s\n" "$WORKSPACE" && printf "Files: app.py .env requirements.txt start.sh .gitignore app.sqlite3\n"
