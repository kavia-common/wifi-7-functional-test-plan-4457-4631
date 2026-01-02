#!/usr/bin/env bash
set -euo pipefail
# Validation: start app, probe /health, run tests, stop server and emit JSON result
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "${WORKSPACE}"
VENV_PY="${WORKSPACE}/.venv/bin/python"
START_SH="${WORKSPACE}/start.sh"
PORT="${TEST_PORT:-5000}"
HEALTH_URL="http://127.0.0.1:${PORT}/health"
LOG="/tmp/coredoc_server_$$_$(date +%s).log"
HEALTH_TMP="/tmp/coredoc_health_$$.txt"
TESTS_FLAG="/tmp/coredoc_tests_passed_$$.txt"
RESULT_FILE="/tmp/coredoc_validation_result.json"
trap 'rm -f "${HEALTH_TMP}" "${TESTS_FLAG}"' EXIT

# Ensure start.sh exists and is executable
if [ ! -x "${START_SH}" ]; then
  echo "ERROR: ${START_SH} not found or not executable" >&2
  exit 2
fi

# Start server in its own session so we can kill the process group later
setsid bash -lc "${START_SH}" >"${LOG}" 2>&1 &
SERVER_PID=$!

# wait for health up to ~30s (150 * 0.2s)
for i in {1..150}; do
  if curl -sS --max-time 1 "${HEALTH_URL}" -o "${HEALTH_TMP}" 2>/dev/null; then
    break
  fi
  sleep 0.2
done

if [ ! -s "${HEALTH_TMP}" ]; then
  echo "ERROR: server did not respond; see ${LOG}" >&2
  tail -n 200 "${LOG}" >&2 || true
  PGID=$(ps -o pgid= -p ${SERVER_PID} | tr -d ' ' || true)
  if [ -n "${PGID}" ]; then sudo kill -- -"${PGID}" >/dev/null 2>&1 || true; fi
  exit 3
fi

PGID=$(ps -o pgid= -p ${SERVER_PID} | tr -d ' ' || true)

# Run tests using venv python if available
RC=0
if [ -x "${VENV_PY}" ]; then
  "${VENV_PY}" -m pytest -q || RC=$?
else
  pytest -q || RC=$?
fi

if [ ${RC} -eq 0 ]; then
  echo true >"${TESTS_FLAG}"
else
  echo false >"${TESTS_FLAG}"
fi

# Emit JSON result with typed boolean
python3 - <<PY >"${RESULT_FILE}"
import json
with open('${HEALTH_TMP}','r') as f:
    server_response = f.read()
with open('${TESTS_FLAG}','r') as f:
    tests_passed = f.read().strip().lower() == 'true'
print(json.dumps({'server_response': server_response, 'tests_passed': tests_passed}))
PY

# Shutdown server group gracefully (TERM then KILL fallback)
if [ -n "${PGID}" ]; then
  sudo kill -- -"${PGID}" >/dev/null 2>&1 || true
  for i in {1..25}; do
    if ! ps -p ${SERVER_PID} >/dev/null 2>&1; then break; fi
    sleep 0.2
  done
  if ps -p ${SERVER_PID} >/dev/null 2>&1; then
    sudo kill -KILL -- -"${PGID}" >/dev/null 2>&1 || true
  fi
fi

echo "VALIDATION_RESULT_FILE=${RESULT_FILE}"
# show last lines of server log to help debugging
tail -n 50 "${LOG}" || true
