#!/usr/bin/env bash
set -euo pipefail

# Validation script - starts app via start.sh (which creates a pidfile), polls for pidfile,
# probes /health, captures HTTP code/body, and performs scoped shutdown preferring pidfile PID.
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WS"
LOGFILE="/tmp/corehub_gunicorn.log"
: >"$LOGFILE"

# Start provided start.sh in background and capture its background PID so we can limit shutdown scope.
# start.sh is expected to exec gunicorn and create $WS/gunicorn.pid for master process.
"$WS/start.sh" >>"$LOGFILE" 2>&1 &
START_PID=$!
PIDFILE="$WS/gunicorn.pid"

# Wait for pidfile up to 10s
i=0
while [ $i -lt 10 ] && [ ! -f "$PIDFILE" ]; do
  sleep 1
  i=$((i+1))
done

GPID=""
if [ -f "$PIDFILE" ]; then
  GPID=$(cat "$PIDFILE" 2>/dev/null || true)
fi

# Probe HTTP endpoint up to 30s for healthy response
MAX_WAIT=30
j=0
HTTP_CODE=000
HTTP_BODY=""
while [ $j -lt $MAX_WAIT ]; do
  # short connect timeout to avoid long hangs
  RESP=$(curl -sS -m 2 -w "\n%{http_code}" http://127.0.0.1:8000/health || true)
  if [ -n "$RESP" ]; then
    HTTP_CODE=$(printf "%s" "$RESP" | tail -n1)
    HTTP_BODY=$(printf "%s" "$RESP" | sed '$d')
  fi
  if [ "$HTTP_CODE" = "200" ]; then
    break
  fi
  sleep 1
  j=$((j+1))
done

if [ "$HTTP_CODE" != "200" ]; then
  echo "health check failed: status=$HTTP_CODE" >&2
  echo "--- last log lines ---" >&2
  tail -n 200 "$LOGFILE" >&2 || true

  # Scoped shutdown: prefer pidfile PID then START_PID
  if [ -n "$GPID" ]; then
    echo "Attempting graceful shutdown of PID from pidfile: $GPID" >&2
    kill "$GPID" 2>/dev/null || true
  else
    echo "Pidfile not found or empty; attempting to stop start.sh background PID: $START_PID" >&2
    kill "$START_PID" 2>/dev/null || true
  fi

  sleep 1
  # escalate to SIGKILL if still alive
  if [ -n "$GPID" ] && kill -0 "$GPID" 2>/dev/null; then
    echo "Escalating to SIGKILL for $GPID" >&2
    kill -9 "$GPID" 2>/dev/null || true
  fi
  if kill -0 "$START_PID" 2>/dev/null; then
    echo "Escalating to SIGKILL for start.sh background PID $START_PID" >&2
    kill -9 "$START_PID" 2>/dev/null || true
  fi
  exit 2
fi

# Evidence output
echo "HTTP_CODE:$HTTP_CODE"
echo "HTTP_BODY:$HTTP_BODY"
echo "--- log tail ---"
tail -n 50 "$LOGFILE" || true

# Clean shutdown: prefer pidfile
if [ -n "$GPID" ]; then
  kill "$GPID" 2>/dev/null || true
else
  kill "$START_PID" 2>/dev/null || true
fi
sleep 2
# escalate if still running
if [ -n "$GPID" ] && kill -0 "$GPID" 2>/dev/null; then
  kill -9 "$GPID" 2>/dev/null || true
fi
if kill -0 "$START_PID" 2>/dev/null; then
  kill -9 "$START_PID" 2>/dev/null || true
fi
wait "$START_PID" 2>/dev/null || true
