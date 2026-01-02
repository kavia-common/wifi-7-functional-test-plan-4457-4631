#!/usr/bin/env bash
set -euo pipefail
# idempotent scaffolding for workspace; uses container-provided WORKSPACE path
WORKSPACE="/home/kavia/workspace/code-generation/wifi-7-functional-test-plan-4457-4631/CoreDocumentation&GovernanceHub"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# create venv if missing
if [ ! -d "$WORKSPACE/.venv" ]; then
  python3 -m venv "$WORKSPACE/.venv" || { echo "ERROR: failed to create venv" >&2; exit 2; }
fi
# pinned requirements
cat > "$WORKSPACE/requirements.txt" <<'EOF'
flask==2.3.3
pytest==7.4.0
requests==2.31.0
EOF
# scaffold app.py
cat > "$WORKSPACE/app.py" <<'PY'
from flask import Flask, jsonify, request
import json, os
app = Flask(__name__)
# allow tests to override artifact path before importing
default_path = os.path.join(os.path.dirname(__file__), 'artifacts.json')
DATA_FILE = os.environ.get('COREDOC_ARTIFACTS', default_path)
@app.route('/health', methods=['GET'])
def health():
    return jsonify(status='ok')
@app.route('/artifacts', methods=['GET','POST'])
def artifacts():
    if request.method == 'POST':
        payload = request.get_json() or {}
        data = []
        if os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE,'r') as f:
                    data = json.load(f)
            except Exception:
                data = []
        data.append(payload)
        with open(DATA_FILE,'w') as f:
            json.dump(data, f)
        return jsonify(result='stored'), 201
    else:
        if os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE,'r') as f:
                    return jsonify(json.load(f))
            except Exception:
                return jsonify([])
        return jsonify([])
if __name__ == '__main__':
    port = int(os.environ.get('TEST_PORT', '5000'))
    app.run(host='0.0.0.0', port=port)
PY
# .gitignore
cat > "$WORKSPACE/.gitignore" <<'EOF'
.venv
__pycache__
artifacts.json
*.pyc
EOF
# start script uses venv-local flask binary to avoid global ambiguity
cat > "$WORKSPACE/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="
