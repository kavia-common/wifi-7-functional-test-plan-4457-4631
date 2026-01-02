#!/usr/bin/env bash
set -euo pipefail
# validation: ensure deps import, start run-bg.sh, poll readiness, show evidence, stop gracefully
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
VENV_PY="$WORKSPACE/.venv/bin/python"
LOG="$WORKSPACE/.devserver.log"
PIDFILE="$WORKSPACE/.devserver.pid"
TIMEOUT=${DEV_SERVER_TIMEOUT:-30}
# 1) venv python presence
if [ ! -x "$VENV_PY" ]; then
  echo "ERROR: venv python missing at $VENV_PY; run scaffold step" >&2
  exit 2
fi
# 2) ensure dependencies importable
"$VENV_PY" - <<'PY'
import importlib, sys
missing=[]
for pkg in ("flask","requests"):
    try:
        importlib.import_module(pkg)
    except Exception as e:
        missing.append((pkg,str(e)))
if missing:
    for p,e in missing:
        print(f"ERROR: missing {p}: {e}", file=sys.stderr)
    sys.exit(2)
print('deps_ok')
PY
# 3) start background server idempotently via run-bg.sh
if [ ! -x ./run-bg.sh ]; then
  echo "ERROR: run-bg.sh missing or not executable in workspace" >&2
  exit 3
fi
# run run-bg.sh and capture its exit for diagnostics
if ! ./run-bg.sh; then
  echo "ERROR: run-bg.sh failed" >&2
  tail -n 200 "$LOG" || true
  exit 4
fi
# 4) poll readiness
ready=0
end=$((SECONDS+TIMEOUT))
while [ $SECONDS -lt $end ]; do
  if curl -sS --fail http://127.0.0.1:5000/health >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "ERROR: server failed to become ready within ${TIMEOUT}s; tailing log:" >&2
  tail -n 200 "$LOG" || true
  # attempt to cleanup PID if present
  if [ -f "$PIDFILE" ]; then
    echo "PID file present at $PIDFILE; content:" >&2
    cat "$PIDFILE" 2>/dev/null || true
  fi
  exit 5
fi
# 5) evidence: fetch health response and show log tail
RESP=$(curl -sS http://127.0.0.1:5000/health || true)
echo "health_response:${RESP}"
echo "--- server log tail ---"
tail -n 50 "$LOG" || true
# 6) graceful shutdown with verification of PID ownership
if [ -f "$PIDFILE" ]; then
  pid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "${pid:-}" ]; then
    if ps -p "$pid" -o comm= | grep -i -E 'python|python3' >/dev/null 2>&1; then
      kill "$pid" 2>/dev/null || true
      # wait up to ~5s for exit (10 * 0.5s)
      for i in {1..10}; do
        if ! kill -0 "$pid" 2>/dev/null; then
          break
        fi
        sleep 0.5
      done
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
    else
      echo "WARNING: PID $pid is not a python process; skipping kill" >&2
    fi
  else
    echo "WARNING: PID file exists but is empty" >&2
  fi
  rm -f "$PIDFILE" || true
else
  echo "WARNING: PID file not found; server may have exited already" >&2
fi
# final: ensure server not running on port 5000
if command -v ss >/dev/null 2>&1; then
  if ss -ltnp | grep -E ':5000\s' >/dev/null 2>&1; then
    echo "WARNING: something still listening on port 5000" >&2
    ss -ltnp | grep -E ':5000\s' || true
  fi
fi
echo "validation: SUCCESS"
