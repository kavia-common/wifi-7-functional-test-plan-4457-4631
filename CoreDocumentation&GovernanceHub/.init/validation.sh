#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
VENV_PY="$WORKSPACE/.venv/bin/python"
[ -x "$VENV_PY" ] || { echo "ERROR: VENV_PY not found: $VENV_PY" >&2; exit 3; }
ENVFILE="$WORKSPACE/.env"
APP_PORT=5000
if [ -f "$ENVFILE" ]; then
  APP_PORT=$(awk -F= '/^APP_PORT=/{gsub(/\r/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}' "$ENVFILE" | head -n1 || true)
  APP_PORT=${APP_PORT:-5000}
fi
LOG="$WORKSPACE/server.log"
# Start in new process group
setsid "$VENV_PY" "$WORKSPACE/app.py" > "$LOG" 2>&1 &
APP_PID=$!
# Determine PGID robustly
PGID=$(ps -o pgid= -p ${APP_PID} 2>/dev/null || true)
PGID=$(echo "$PGID" | tr -d ' ')
if ! [[ "$PGID" =~ ^[0-9]+$ ]]; then
  PGID=""
fi
# wait-for-port loop
START=0; TIMEOUT=${VALIDATION_TIMEOUT:-10}
while [ $START -lt $TIMEOUT ]; do
  if curl -sS --max-time 1 http://127.0.0.1:${APP_PORT}/ >/dev/null 2>&1; then break; fi
  START=$((START+1)); sleep 1
done
if ! curl -sS --max-time 1 http://127.0.0.1:${APP_PORT}/ >/dev/null 2>&1; then
  echo "VALIDATION_FAILED: server did not start within ${TIMEOUT}s" >&2
  tail -n 200 "$LOG" >&2 || true
  if [ -n "$PGID" ]; then
    kill -TERM -"$PGID" 2>/dev/null || true; sleep 1; kill -9 -"$PGID" 2>/dev/null || true
  else
    kill ${APP_PID} 2>/dev/null || true; sleep 1; kill -9 ${APP_PID} 2>/dev/null || true
  fi
  exit 2
fi
BODY_FILE="$WORKSPACE/validation_body.tmp"
HTTP_STATUS=$(curl -sS -w "%{http_code}" -o "$BODY_FILE" http://127.0.0.1:${APP_PORT}/ || true)
BODY_PREVIEW=$(head -c 200 "$BODY_FILE" | tr -d '\n' || true)
# Stop server group robustly
if [ -n "$PGID" ]; then
  kill -TERM -"$PGID" 2>/dev/null || true; sleep 1 || true;
  # if still running, escalate
  if ps -o pgid= -p ${APP_PID} >/dev/null 2>&1; then kill -9 -"$PGID" 2>/dev/null || true; fi
else
  kill ${APP_PID} 2>/dev/null || true; sleep 1 || true;
  if ps -p ${APP_PID} >/dev/null 2>&1; then kill -9 ${APP_PID} 2>/dev/null || true; fi
fi
# Output concise evidence
if [ "$HTTP_STATUS" = "200" ]; then
  echo "VALIDATION_OK: status=${HTTP_STATUS} body_preview=${BODY_PREVIEW}"
  rm -f "$BODY_FILE"
  exit 0
else
  echo "VALIDATION_FAILED: status=${HTTP_STATUS} body_preview=${BODY_PREVIEW}" >&2
  tail -n 200 "$LOG" >&2 || true
  rm -f "$BODY_FILE"
  exit 2
fi
