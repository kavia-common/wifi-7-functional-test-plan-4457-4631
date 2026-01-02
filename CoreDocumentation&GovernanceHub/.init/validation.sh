#!/usr/bin/env bash
set -euo pipefail

# Validation script: build docs, run tests, start app robustly, probe endpoints, capture evidence, stop cleanly
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_PY="$WORKSPACE/.venv/bin/python"
cd "$WORKSPACE"

# Ensure logs dir
mkdir -p "$WORKSPACE/logs"
LOG="$WORKSPACE/logs/server.log"
TIMEOUT=${VALIDATION_TIMEOUT:-30}

# Build docs if mkdocs available (non-fatal)
if command -v mkdocs >/dev/null 2>&1; then
  mkdocs --version || true
  mkdocs build -f "$WORKSPACE"/mkdocs.yml -d "$WORKSPACE"/site >/dev/null 2>&1 || echo 'mkdocs build failed' >&2
else
  echo 'mkdocs not found in PATH; skipping docs build' >&2
fi

# Run tests via venv python; let failures surface (non-masked)
if [ -x "$VENV_PY" ]; then
  "$VENV_PY" -m pytest -q
else
  echo "venv python not found at $VENV_PY" >&2
  exit 22
fi

# Clean any stale pid files
rm -f "$WORKSPACE/.server.pid" "$WORKSPACE/.server.pgid"

# Launch server in background using venv python. Background subshell so child is the server process.
# Use exec so the subshell is replaced by the python process, making CHILD the real pid.
( exec "$VENV_PY" -m flask run --host 0.0.0.0 --port 8000 >"$LOG" 2>&1 ) &
CHILD=$!

# Derive PGID numerically
PGID=$(ps -o pgid= "$CHILD" 2>/dev/null | tr -d ' ' || true)

# Defensive numeric checks
if ! [[ "$CHILD" =~ ^[0-9]+$ ]]; then
  echo 'invalid child pid' >&2
  # ensure we try to cleanup by pkill
  pkill -f "${VENV_PY}" >/dev/null 2>&1 || true
  exit 20
fi
if [ -z "$PGID" ] || ! [[ "$PGID" =~ ^[0-9]+$ ]]; then
  PGID=''
fi

# Persist numeric PID and PGID (PGID may be empty)
printf "%s\n" "$CHILD" > "$WORKSPACE/.server.pid"
printf "%s\n" "${PGID}" > "$WORKSPACE/.server.pgid"

# Wait for readiness probe
SEEN=0
for i in $(seq 1 $TIMEOUT); do
  if curl -sS --max-time 2 --fail http://127.0.0.1:8000/health >/dev/null 2>&1; then
    SEEN=1; break
  fi
  if (( i % 5 == 0 )); then
    echo "--- tail of server log (last 20 lines) after ${i}s ---"
    tail -n 20 "$LOG" || true
  fi
  sleep 1
done

if [ "$SEEN" -ne 1 ]; then
  echo "server failed to become ready within ${TIMEOUT}s, tailing logs:" >&2
  tail -n 200 "$LOG" >&2 || true
  # Attempt safe cleanup: use PGID if numeric, else try pkill
  if [[ "$PGID" =~ ^[0-9]+$ ]]; then
    kill -TERM -"$PGID" >/dev/null 2>&1 || true
  else
    pkill -f "${VENV_PY}" >/dev/null 2>&1 || true
  fi
  rm -f "$WORKSPACE/.server.pid" "$WORKSPACE/.server.pgid"
  exit 21
fi

# Probe endpoints and print evidence
echo "--- /health ---"
curl -sS --max-time 5 http://127.0.0.1:8000/health || { echo 'health probe failed' >&2; }

echo "--- /dbinfo ---"
curl -sS --max-time 5 http://127.0.0.1:8000/dbinfo || { echo 'dbinfo probe failed' >&2; }

# Stop server: prefer PGID kill if available, otherwise pkill
if [[ "$PGID" =~ ^[0-9]+$ ]]; then
  kill -TERM -"$PGID" >/dev/null 2>&1 || true
else
  pkill -f "${VENV_PY}" >/dev/null 2>&1 || true
fi

# Give processes a moment to stop then ensure no lingering child
sleep 1
# Final defensive cleanup: if CHILD still exists, kill it
if ps -p "$CHILD" >/dev/null 2>&1; then
  kill -TERM "$CHILD" >/dev/null 2>&1 || true
fi

rm -f "$WORKSPACE/.server.pid" "$WORKSPACE/.server.pgid"

echo "validation: success"
