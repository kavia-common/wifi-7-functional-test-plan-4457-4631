#!/usr/bin/env bash
set -euo pipefail

# Test runner for background Flask dev server health check
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
cd "$WORKSPACE"
# Activate venv if present
if [ -f "$WORKSPACE/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$WORKSPACE/.venv/bin/activate"
fi

mkdir -p tests
cat > tests/test_health.py <<'EOF'
import requests, subprocess, time, os, signal, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
LOG = os.path.join(ROOT, '.devserver.log')
PIDFILE = os.path.join(ROOT, '.devserver.pid')
TIMEOUT = int(os.environ.get('DEV_SERVER_TIMEOUT', '30'))

def start_bg():
    # remove stale pid if invalid
    if os.path.exists(PIDFILE):
        try:
            with open(PIDFILE) as f: pid=int(f.read().strip())
            os.kill(pid, 0)
            # verify it's python
            import subprocess
            cmd = subprocess.check_output(['ps','-p',str(pid),'-o','cmd=']).decode()
            if 'python' in cmd or 'flask' in cmd:
                return pid
        except Exception:
            try: os.remove(PIDFILE)
            except Exception: pass
    # start run-bg.sh
    p = subprocess.Popen(["/bin/bash", os.path.join(ROOT,'run-bg.sh')])
    # wait for PIDFILE to be written and validated
    deadline = time.time() + TIMEOUT
    while time.time() < deadline:
        if os.path.exists(PIDFILE):
            try:
                with open(PIDFILE) as f: pid=int(f.read().strip())
                import subprocess
                cmd = subprocess.check_output(['ps','-p',str(pid),'-o','cmd=']).decode()
                if 'python' in cmd or 'flask' in cmd:
                    return pid
            except Exception:
                pass
        time.sleep(0.5)
    raise RuntimeError('server not ready; logs:\n'+(open(LOG).read() if os.path.exists(LOG) else 'no log'))


def stop_pid(pid):
    try:
        os.kill(pid, signal.SIGTERM)
    except Exception:
        return
    for _ in range(10):
        try:
            os.kill(pid, 0)
            time.sleep(0.5)
        except Exception:
            return
    try:
        os.kill(pid, signal.SIGKILL)
    except Exception:
        pass


def test_health_check():
    pid = start_bg()
    try:
        r = requests.get('http://127.0.0.1:5000/health', timeout=5)
        assert r.status_code == 200
        assert r.json().get('status') == 'ok'
    finally:
        try:
            stop_pid(pid)
        except Exception:
            pass
        if os.path.exists(PIDFILE):
            try: os.remove(PIDFILE)
            except Exception: pass

if __name__ == '__main__':
    try:
        test_health_check()
        print('tests_ok')
    except Exception as e:
        print('test_failed', e)
        sys.exit(1)
EOF

# Run pytest quietly and surface logs on failure
pytest -q tests || (echo "pytest failed; see $WORKSPACE/.devserver.log" >&2 && exit 4)
