#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WS"
VENV="$WS/.venv"
LOG=/tmp/cdgh_app.log
PIDFILE="$WS/run.pid"
PORT=8000
HOST=127.0.0.1
# if already running, do nothing
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" >/dev/null 2>&1; then
  echo "already running"
  exit 0
fi
setsid "$VENV/bin/python" -m flask run --host=$HOST --port=$PORT >"$LOG" 2>&1 &
PID=$!
echo "$PID" >"$PIDFILE"
