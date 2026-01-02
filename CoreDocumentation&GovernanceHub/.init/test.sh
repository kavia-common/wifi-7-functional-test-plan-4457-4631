#!/usr/bin/env bash
set -euo pipefail

# Run the provided pytest test using the project venv python to avoid launcher issues.
# Uses the authoritative workspace path from the Container Context.
WORKDIR="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKDIR"

mkdir -p "$WORKDIR/tests"
cat > "$WORKDIR/tests/test_app.py" <<'PY'
import subprocess, time, os, requests, signal, socket

def start_server(logfile):
    run_sh = os.path.join(os.getcwd(), 'run.sh')
    f = open(logfile, 'wb')
    proc = subprocess.Popen(['/bin/bash', run_sh], stdout=f, stderr=f, preexec_fn=os.setsid)
    return proc, f

def wait_for_port(host, port, timeout=30):
    start = time.time(); delay = 0.1
    while time.time() - start < timeout:
        try:
            with socket.create_connection((host, port), timeout=1):
                return True
        except Exception:
            time.sleep(delay); delay = min(delay * 1.5, 1.0)
    return False

def test_index(tmp_path):
    log = str(tmp_path / 'srv.log')
    proc, fh = start_server(log)
    try:
        time.sleep(0.2)
        if proc.poll() is not None:
            fh.close(); raise AssertionError('server process exited prematurely')
        pgid = os.getpgid(proc.pid)
        assert pgid > 0
        assert wait_for_port('127.0.0.1', 5000, timeout=30), 'server did not open port'
        r = requests.get('http://127.0.0.1:5000/', timeout=5)
        assert r.status_code == 200
        assert 'CoreDocumentation' in r.json().get('service','')
    finally:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except Exception:
            pass
        try:
            proc.wait(timeout=5)
        except Exception:
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            except Exception:
                pass
        fh.close()
PY

# Default SAFE_WORKDIR to authoritative WORKDIR if not set by earlier steps
SAFE_WORKDIR=${SAFE_WORKDIR:-"$WORKDIR"}

# Ensure venv python exists before invoking pytest
if [ ! -x "$SAFE_WORKDIR/.venv/bin/python" ]; then
  echo "ERROR: venv python not found at $SAFE_WORKDIR/.venv/bin/python" >&2
  exit 2
fi

# Run tests with venv python to avoid launcher wrappers
"$SAFE_WORKDIR/.venv/bin/python" -m pytest -q tests
