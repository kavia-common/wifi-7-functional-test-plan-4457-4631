#!/usr/bin/env bash
set -euo pipefail

WORKDIR="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKDIR"
# ensure server started (idempotent - start.sh should handle already-running)
"$WORKDIR/start.sh" >/dev/null 2>&1 || true
PIDFILE="$WORKDIR/server.pid"
PGIDFILE="$WORKDIR/server.pgid"
EVIDENCE="$WORKDIR/validation_evidence.txt"
RESP="$WORKDIR/validation_resp.json"
LOGFILE="$WORKDIR/server.log"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
else
  echo "ERROR: no pidfile" >&2; exit 2
fi
if [ -f "$PGIDFILE" ]; then
  PGID=$(cat "$PGIDFILE")
else
  PGID=$(ps -o pgid= -p "$PID" | tr -d ' ')
fi

# wait for readiness (poll root endpoint)
MAX=30; i=0
while [ $i -lt $MAX ]; do
  if curl -sS http://127.0.0.1:5000/ -o "$RESP" 2>/dev/null; then
    # ensure response is valid JSON (quick check)
    if python3 -c "import sys,json; json.load(open('$RESP'))" >/dev/null 2>&1; then
      break
    fi
  fi
  sleep 0.5; i=$((i+1))
done
if [ $i -ge $MAX ]; then
  echo "ERROR: server did not become ready" >&2
  kill -TERM -"$PGID" 2>/dev/null || true
  exit 3
fi

# persist evidence using python3 to produce a single-line evidence file
python3 - <<'PY'
import json,sys
p='validation_resp.json'
try:
    j=json.load(open(p))
    open('validation_evidence.txt','w').write('VALIDATION_OK: '+json.dumps(j))
    print('VALIDATION_OK: validation_evidence.txt')
except Exception as e:
    print('VALIDATION_FAIL:',e,file=sys.stderr)
    sys.exit(1)
PY

# stop server group gracefully
kill -TERM -"$PGID" 2>/dev/null || true
sleep 1
# if still present, force kill
if ps -o pgid= -p "$PID" >/dev/null 2>&1; then
  kill -KILL -"$PGID" 2>/dev/null || true
fi
# cleanup
rm -f "$RESP" || true
exit 0
