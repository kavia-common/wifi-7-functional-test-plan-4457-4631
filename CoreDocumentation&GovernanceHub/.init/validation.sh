#!/usr/bin/env bash
set -euo pipefail
# validation: start app (isolated), poll-ready, smoke test, run pytest, and clean stop (process-group safe)
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_BIN="$WS/.venv/bin"
GUNICORN="$VENV_BIN/gunicorn"
UVICORN="$VENV_BIN/uvicorn"
PYTEST="$VENV_BIN/pytest"
PIDFILE="$WS/.venv/gunicorn.pid"
LOGFILE="$WS/.venv/gunicorn.log"
cd "$WS"
# choose server: prefer gunicorn, fallback to uvicorn, then flask
SERVER_TYPE=""
if [ -x "$GUNICORN" ]; then SERVER_TYPE=gunicorn; fi
if [ -z "$SERVER_TYPE" ] && [ -x "$UVICORN" ]; then SERVER_TYPE=uvicorn; fi
if [ -z "$SERVER_TYPE" ]; then SERVER_TYPE=flask; fi
# ensure no stale pid
[ -f "$PIDFILE" ] && rm -f "$PIDFILE" || true
RETRIES=60
SLEEP=0.5
READY=0
SERVER_PID=0
case "$SERVER_TYPE" in
  gunicorn)
    LOGFILE="$LOGFILE"
    # start gunicorn in new session (setsid) so children share PGID
    setsid "$GUNICORN" --bind 127.0.0.1:8000 --pid "$PIDFILE" app.main:app --worker-tmp-dir /dev/shm --log-level warning >"$LOGFILE" 2>&1 &
    SERVER_PID=$!
    ;;
  uvicorn)
    LOGFILE="$WS/.venv/uvicorn.log"
    setsid "$UVICORN" app.main:app --host 127.0.0.1 --port 8000 >"$LOGFILE" 2>&1 &
    SERVER_PID=$!
    ;;
  flask)
    LOGFILE="$WS/.venv/flask.log"
    # use the workspace venv python if available
    PY="$VENV_BIN/python3"
    if [ ! -x "$PY" ]; then PY=python3; fi
    setsid "$PY" -m flask --app app.main run --host=127.0.0.1 --port=8000 --no-reload >"$LOGFILE" 2>&1 &
    SERVER_PID=$!
    ;;
esac
# wait for readiness
for i in $(seq 1 $RETRIES); do
  if curl -sS -f http://127.0.0.1:8000/ >/dev/null 2>&1; then READY=1; break; fi
  sleep $SLEEP
done
if [ "$READY" -ne 1 ]; then
  echo "server failed to become ready; dumping logs (first 200 lines):" >&2
  [ -f "$LOGFILE" ] && sed -n '1,200p' "$LOGFILE" >&2 || true
  # try to cleanup
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE" 2>/dev/null || true)
    if [ -n "$PID" ]; then
      PGID=$(ps -o pgid= "$PID" 2>/dev/null | tr -d ' ' || true)
      if [ -n "$PGID" ]; then kill -TERM -"$PGID" 2>/dev/null || true; fi
    fi
  else
    kill -TERM "$SERVER_PID" 2>/dev/null || true
  fi
  exit 6
fi
# smoke test
curl -sS -f http://127.0.0.1:8000/ >/dev/null
# run pytest via venv-local (prefer venv pytest, fallback to system pytest)
if [ -x "$PYTEST" ]; then
  "$PYTEST" -q "$WS/tests"
else
  command -v pytest >/dev/null 2>&1 || (echo "pytest not found in venv or PATH" >&2 && exit 7)
  pytest -q "$WS/tests"
fi
# shutdown: prefer pidfile PGID, else server pid PGID
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  PGID=$(ps -o pgid= "$PID" 2>/dev/null | tr -d ' ' || true)
  if [ -n "$PGID" ]; then
    kill -TERM -"$PGID" 2>/dev/null || true
    sleep 0.5
    kill -KILL -"$PGID" 2>/dev/null || true
  else
    kill -TERM "$PID" 2>/dev/null || true
    sleep 0.5
    kill -KILL "$PID" 2>/dev/null || true
  fi
  rm -f "$PIDFILE" || true
else
  if [ -n "$SERVER_PID" ] && ps -p "$SERVER_PID" >/dev/null 2>&1; then
    PGID=$(ps -o pgid= "$SERVER_PID" 2>/dev/null | tr -d ' ' || true)
    if [ -n "$PGID" ]; then
      kill -TERM -"$PGID" 2>/dev/null || true
      sleep 0.5
      kill -KILL -"$PGID" 2>/dev/null || true
    else
      kill -TERM "$SERVER_PID" 2>/dev/null || true
      sleep 0.5
      kill -KILL "$SERVER_PID" 2>/dev/null || true
    fi
  fi
fi
wait 2>/dev/null || true
echo "validation: success"
