from .main import app

@app.route('/')
def index():
    return {'status': 'ok', 'app': 'CoreDocumentation&GovernanceHub'}
