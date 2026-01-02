#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
PIDFILE="$WORKSPACE/.uvicorn.pid"
PORT=8000
# if pidfile exists and points to running process, terminate gracefully
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then
    kill -TERM "$PID" || true
    for i in {1..10}; do
      if ! ps -p "$PID" >/dev/null 2>&1; then rm -f "$PIDFILE"; exit 0; fi
      sleep 0.5
    done
    kill -KILL "$PID" >/dev/null 2>&1 || true
    rm -f "$PIDFILE" || true
    exit 0
  fi
fi
# fallback: find processes listening on PORT and kill
PIDS=""
if command -v ss >/dev/null 2>&1; then
  PIDS=$(ss -ltnp 2>/dev/null | awk -v p=":$PORT" '$0~p{for(i=1;i<=NF;i++) if($i~/pid=/){split($i,a,",");for(j in a) if(a[j]~/pid=/){split(a[j],b,/pid=|,/);print b[2]}}}') || true
elif command -v netstat >/dev/null 2>&1; then
  PIDS=$(netstat -ltnp 2>/dev/null | awk -v p=":$PORT" '$0~p{for(i=1;i<=NF;i++) if($i~/pid=/){split($i,a,",");for(j in a) if(a[j]~/pid=/){split(a[j],b,/pid=|,/);print b[2]}}}') || true
fi
if [ -n "$PIDS" ]; then
  for p in $PIDS; do kill -TERM "$p" >/dev/null 2>&1 || true; done
fi
rm -f "$PIDFILE" || true
exit 0
