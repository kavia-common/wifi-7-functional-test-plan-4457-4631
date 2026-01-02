#!/usr/bin/env bash
set -euo pipefail

# Validation script: build/start/healthcheck/run tests/stop using absolute workspace paths
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
PIDFILE="$WORKSPACE/.uvicorn.pid"
LOGFILE="$WORKSPACE/uvicorn.log"
PORT=8000
RETRIES=20
SLEEP_MS=0.5

# warn about redis broker availability but do not fail
REDIS_OK=0
if command -v redis-cli >/dev/null 2>&1; then
  if redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; then REDIS_OK=1; else echo "warning: redis not responding; celery broker unavailable" >&2; REDIS_OK=0; fi
else
  if pgrep -f redis-server >/dev/null 2>&1; then REDIS_OK=1; else echo "warning: redis-cli/redis-server not found; celery broker unavailable" >&2; REDIS_OK=0; fi
fi

# start server
if [ ! -x "./start.sh" ]; then echo "error: ./start.sh not found or not executable" >&2; exit 2; fi
./start.sh || (echo "start.sh returned non-zero" >&2; exit 3)

# wait for LISTEN and /health
OK=0
for i in $(seq 1 "$RETRIES"); do
  # optional check for LISTEN; don't fail on missing ss/netstat
  if command -v ss >/dev/null 2>&1; then ss -ltn | grep -E ":$PORT( |$)" >/dev/null 2>&1 || true; fi
  if curl -sS -f "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then OK=1; break; fi
  sleep "$SLEEP_MS"
done

if [ "$OK" -ne 1 ]; then
  echo "health check failed; collecting diagnostics..." >&2
  if command -v ss >/dev/null 2>&1; then ss -ltnp 2>/dev/null | sed -n '1,200p' >&2 || true; fi
  if command -v netstat >/dev/null 2>&1; then netstat -ltnp 2>/dev/null | sed -n '1,200p' >&2 || true; fi
  ps aux | grep -E 'uvicorn|app.main' | sed -n '1,200p' >&2 || true
  echo "--- uvicorn log (tail) ---" >&2
  tail -n 200 "$LOGFILE" 2>/dev/null || true

  # attempt graceful stop
  ./stop.sh >/dev/null 2>&1 || true

  # find PIDs listening on port and kill
  PIDS=""
  if command -v ss >/dev/null 2>&1; then
    PIDS=$(ss -ltnp 2>/dev/null | awk -v p=":$PORT" '$0~p{for(i=1;i<=NF;i++) if($i~/pid=/){split($i,a,",");for(j in a) if(a[j]~/pid=/){split(a[j],b,/pid=|,/);print b[2]}}}') || true
  elif command -v netstat >/dev/null 2>&1; then
    PIDS=$(netstat -ltnp 2>/dev/null | awk -v p=":$PORT" '$0~p{for(i=1;i<=NF;i++) if($i~/pid=/){split($i,a,",");for(j in a) if(a[j]~/pid=/){split(a[j],b,/pid=|,/);print b[2]}}}') || true
  fi
  if [ -n "$PIDS" ]; then
    for p in $PIDS; do kill -TERM "$p" >/dev/null 2>&1 || kill -KILL "$p" >/dev/null 2>&1 || true; done
  fi
  exit 7
fi

# run runtime tests using venv python if available, capture logs
PYBIN="$WORKSPACE/.venv/bin/python"
mkdir -p "$WORKSPACE/tests"
if [ -x "$PYBIN" ]; then
  "$PYBIN" -m pytest tests | tee "$WORKSPACE/tests/pytest_runtime.log" || (echo "runtime pytest failed" >&2; ./stop.sh >/dev/null 2>&1 || true; exit 8)
else
  python3 -m pytest tests | tee "$WORKSPACE/tests/pytest_runtime.log" || (echo "runtime pytest failed" >&2; ./stop.sh >/dev/null 2>&1 || true; exit 8)
fi

# stop server gracefully
./stop.sh >/dev/null 2>&1 || true

# confirm stopped; if pidfile remains try to report and clean
if [ -f "$PIDFILE" ]; then
  PIDVAL="$(cat "$PIDFILE" 2>/dev/null || true)"
  echo "failed to stop uvicorn (pidfile remains): $PIDFILE -> $PIDVAL" >&2
  if [ -n "$PIDVAL" ]; then ps -p "$PIDVAL" -o pid,cmd || true; kill -TERM "$PIDVAL" >/dev/null 2>&1 || true; fi
  sleep 0.5
  if [ -f "$PIDFILE" ]; then rm -f "$PIDFILE" || true; fi
  exit 9
fi

exit 0
