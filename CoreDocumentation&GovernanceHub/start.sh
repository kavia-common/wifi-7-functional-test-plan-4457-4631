#!/usr/bin/env bash
set -euo pipefail
WS="$WS"
VENV_BIN="$WS/.venv/bin"
GUNICORN="$VENV_BIN/gunicorn"
PIDFILE="$WS/.venv/gunicorn.pid"
LOGFILE="$WS/.venv/gunicorn.log"
cd "$WS"
export FLASK_ENV=development
if [ -x "$GUNICORN" ]; then
  # run in new process session so children are grouped
  setsid "$GUNICORN" --bind 127.0.0.1:8000 --pid "$PIDFILE" app.main:app --log-level warning >"$LOGFILE" 2>&1 &
  echo $! > "$WS/.venv/.starter_pid"
  exit 0
else
  # fallback to flask run (uses system python in venv PATH)
  python3 -m flask --app app.main run --host=127.0.0.1 --port=8000 --no-reload >"$LOGFILE" 2>&1 &
  echo $! > "$WS/.venv/.starter_pid"
  exit 0
fi
