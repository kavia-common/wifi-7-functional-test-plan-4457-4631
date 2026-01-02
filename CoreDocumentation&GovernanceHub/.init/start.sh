#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
VENV_DIR="${VENV_DIR:-/opt/venvs/coredoc_govhub}"
PY="$VENV_DIR/bin/python3"
[ -x "$PY" ] || PY="$VENV_DIR/bin/python"
export ARTIFACTS_DIR="$WORKSPACE/artifacts"
export FLASK_DEBUG=${FLASK_DEBUG:-0}
export PORT=${PORT:-5000}
# start wsgi in background, log to /tmp/coredoc_server.log
"$PY" "$WORKSPACE/app/wsgi.py" >/tmp/coredoc_server.log 2>&1 &
echo $! > /tmp/coredoc_server.pid
