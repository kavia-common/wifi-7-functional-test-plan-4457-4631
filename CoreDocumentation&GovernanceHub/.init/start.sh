#!/usr/bin/env bash
set -euo pipefail
# Idempotent start for Flask app: runs run.sh in its own session, writes pid/pgid/log files
WORKDIR="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKDIR"
PIDFILE="$WORKDIR/server.pid"
PGIDFILE="$WORKDIR/server.pgid"
LOGFILE="$WORKDIR/server.log"
# If PID file exists and process is alive, exit 0 (idempotent)
if [ -f "$PIDFILE" ]; then
  oldpid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$oldpid" ] && kill -0 "$oldpid" >/dev/null 2>&1; then
    exit 0
  fi
fi
# Start run.sh in a new session; capture PID, then derive PGID and persist both
setsid /bin/bash "$WORKDIR/run.sh" >"$LOGFILE" 2>&1 &
PID=$!
# small pause to allow kernel to set pgid
sleep 0.2
PGID=$(ps -o pgid= -p "$PID" | tr -d ' ')
if [ -z "$PGID" ]; then
  kill "$PID" 2>/dev/null || true
  echo "ERROR: could not determine PGID" >&2
  exit 2
fi
printf "%s\n" "$PID" > "$PIDFILE"
printf "%s\n" "$PGID" > "$PGIDFILE"
