#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WS"
VENV="$WS/.venv"
# ensure deps present
"$VENV/bin/pip" install --quiet --disable-pip-version-check -r requirements.txt pytest || { echo "deps install failed" >&2; exit 6; }
LOG=/tmp/cdgh_app.log
PORT=8000
HOST=127.0.0.1
PIDFILE="$WS/run.pid"
# robust port-in-use detection
if command -v ss >/dev/null 2>&1; then
  if ss -ltn "sport = :${PORT}" | grep -q LISTEN; then echo "port ${PORT} in use" >&2; exit 7; fi
elif command -v netstat >/dev/null 2>&1; then
  if netstat -ltn 2>/dev/null | grep -E "LISTEN.*:${PORT}\b" >/dev/null 2>&1; then echo "port ${PORT} in use" >&2; exit 7; fi
fi
# attempt to use start script
if [ -x "$WS/start.sh" ]; then
  "$WS/start.sh" >/dev/null 2>&1 || true
fi
# prefer PID file
if [ -f "$PIDFILE" ]; then
  SERVER_PID=$(cat "$PIDFILE")
else
  setsid "$VENV/bin/python" -m flask run --host=127.0.0.1 --port=$PORT >"$LOG" 2>&1 &
  SERVER_PID=$!
  echo "$SERVER_PID" >"$PIDFILE"
fi
# wait for readiness up to 10s
MAX_ATTEMPTS=10
ATTEMPT=0
until curl --silent --fail "http://${HOST}:${PORT}/health" >/dev/null 2>&1; do
  ATTEMPT=$((ATTEMPT+1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "VALIDATION: server failed to start after ${MAX_ATTEMPTS} attempts" >&2
    echo "--- last log lines ---" >&2
    tail -n 200 "$LOG" >&2 || true
    if [ -n "${SERVER_PID:-}" ]; then kill "$SERVER_PID" >/dev/null 2>&1 || true; fi
    rm -f "$PIDFILE" || true
    exit 8
  fi
  sleep 1
done
# evidence
echo "EVIDENCE: root=$(curl -sS http://${HOST}:${PORT}/ | head -c 200)"
echo "EVIDENCE: health=$(curl -sS http://${HOST}:${PORT}/health)"
# stop server gracefully
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE") || true
  kill "$PID" >/dev/null 2>&1 || true
  sleep 1
  if kill -0 "$PID" >/dev/null 2>&1; then
    kill -9 "$PID" >/dev/null 2>&1 || true
  fi
  wait "$PID" 2>/dev/null || true
  rm -f "$PIDFILE" || true
fi
echo "VALIDATION: success"
