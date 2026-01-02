#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WS"
VENV="$WS/.venv"
python3 -m venv "$VENV" || { echo "venv creation failed" >&2; exit 5; }
# upgrade pip/setuptools/wheel quietly
"$VENV/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
# install requirements into venv
"$VENV/bin/pip" install --quiet --disable-pip-version-check -r requirements.txt || { echo "deps install failed" >&2; exit 6; }
# ensure start script executable
[ -f "$WS/start.sh" ] && chmod +x "$WS/start.sh"
