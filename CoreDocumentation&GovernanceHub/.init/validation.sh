#!/usr/bin/env bash
set -euo pipefail
# validation: start WSGI directly with sanitized venv python, poll health JSON, clean shutdown
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
VENV_DIR="${VENV_DIR:-/opt/venvs/coredoc_govhub}"
PY="$VENV_DIR/bin/python3"
[ -x "$PY" ] || PY="$VENV_DIR/bin/python"
if [ ! -x "$PY" ]; then echo "error: venv python missing; run env-001" >&2; exit 2; fi
export ARTIFACTS_DIR="$WORKSPACE/artifacts"
export FLASK_DEBUG=${FLASK_DEBUG:-0}
export PORT=${PORT:-5000}
LOG=/tmp/coredoc_server.log
MAX_WAIT=${MAX_WAIT:-30}
# ensure log file exists and is writable
: >"$LOG" || (echo "error: cannot write $LOG" >&2; exit 3)
# start the app directly (no auto-reloader)
"$PY" "$WORKSPACE/app/wsgi.py" >"$LOG" 2>&1 &
SERVER_PID=$!
# wait for readiness
i=0
interval=1
while [ $i -lt $MAX_WAIT ]; do
  if "$PY" - <<PYCHECK 2>/dev/null
import sys, urllib.request, json
try:
    resp=urllib.request.urlopen('http://127.0.0.1:%s/' % (%s), timeout=2)
    data=json.load(resp)
    sys.exit(0 if data.get('status')=='ok' else 4)
except Exception:
    sys.exit(3)
PYCHECK
  then
    break
  fi
  sleep $interval
  i=$((i+interval))
  if [ $interval -lt 5 ]; then interval=$((interval+1)); fi
done
# final health check
if ! "$PY" - <<PYFINAL 2>/dev/null
import sys, urllib.request, json
try:
    resp=urllib.request.urlopen('http://127.0.0.1:%s/' % (%s), timeout=3)
    data=json.load(resp)
    if data.get('status')!='ok':
        print('validation: unexpected payload', data, file=sys.stderr); sys.exit(4)
    sys.exit(0)
except Exception as e:
    print('validation: health-check failed:', e, file=sys.stderr)
    sys.exit(5)
PYFINAL
then
  RC=1
else
  RC=0
fi
# clean shutdown
kill -TERM "$SERVER_PID" 2>/dev/null || true
sleep 1
kill -KILL "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
if [ $RC -eq 0 ]; then
  echo "validation: success"
  exit 0
else
  echo "--- $LOG ---" >&2
  sed -n '1,200p' "$LOG" >&2 || true
  exit 6
fi
