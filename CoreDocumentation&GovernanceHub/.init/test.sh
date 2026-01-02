#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
VENV_PY="$WORKSPACE/.venv/bin/python"
mkdir -p "$WORKSPACE/tests"
# create pytest in tests/
cat > "$WORKSPACE/tests/test_basic.py" <<'PY'
import subprocess, os, time, requests, signal, pathlib
WORKDIR = pathlib.Path(__file__).resolve().parents[1]
venv_py = str(WORKDIR / '.venv' / 'bin' / 'python')
# load .env safely
env = os.environ.copy()
envfile = WORKDIR / '.env'
if envfile.exists():
    for line in envfile.read_text().splitlines():
        line = line.split('#',1)[0]
        if not line or '=' not in line: continue
        k,v = line.split('=',1); env[k.strip()] = v.strip()
PORT = int(env.get('APP_PORT','5000'))
# Start server in its own process group
cmd = [venv_py, str(WORKDIR / 'app.py')]
# ensure unbuffered python output
env['PYTHONUNBUFFERED'] = '1'
proc = subprocess.Popen(cmd, env=env, preexec_fn=os.setsid)
try:
    deadline = time.time() + float(env.get('TEST_SERVER_TIMEOUT','10'))
    while time.time() < deadline:
        try:
            r = requests.get(f'http://127.0.0.1:{PORT}/', timeout=1.0)
            if r.status_code == 200:
                break
        except Exception:
            time.sleep(0.2)
    else:
        raise RuntimeError('server did not become ready')
    r = requests.get(f'http://127.0.0.1:{PORT}/', timeout=5)
    assert r.status_code == 200
finally:
    try:
        pgid = os.getpgid(proc.pid)
        os.killpg(pgid, signal.SIGTERM)
        proc.wait(timeout=3)
    except Exception:
        try:
            proc.kill()
            proc.wait()
        except Exception:
            pass
PY

# Run pytest using venv python; if venv python missing, exit with clear message
if [ ! -x "$VENV_PY" ]; then
  echo "ERROR: venv python not found at $VENV_PY. Create the venv and install requirements before running tests." >&2
  exit 2
fi
"$VENV_PY" -m pytest -q
