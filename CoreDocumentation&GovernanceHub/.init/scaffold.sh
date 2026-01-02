#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WS/data"
VENV_PY="$WS/.venv/bin/python"
[ -x "$VENV_PY" ] || { echo "venv python missing" >&2; exit 4; }
DBPATH="$WS/data/coredoc.db"
if [ ! -f "$DBPATH" ]; then
  export DBPATH
  "$VENV_PY" - <<'PY'
import os, sqlite3
DB = os.environ['DBPATH']
conn = sqlite3.connect(DB)
cur = conn.cursor()
cur.execute('''CREATE TABLE IF NOT EXISTS tests (id INTEGER PRIMARY KEY, name TEXT, status TEXT, created_ts TEXT)''')
conn.commit()
conn.close()
print('initialized')
PY
fi
