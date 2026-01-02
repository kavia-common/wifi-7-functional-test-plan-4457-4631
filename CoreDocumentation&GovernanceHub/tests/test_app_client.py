import os
import pytest
# set artifact path before importing app to ensure isolation
def _prepare_env(tmp_path):
    art = tmp_path / 'artifacts.json'
    os.environ['COREDOC_ARTIFACTS'] = str(art)
    return str(art)

@pytest.fixture
def client(tmp_path):
    _prepare_env(tmp_path)
    # import after env is set
    from app import app
    app.testing = True
    with app.test_client() as c:
        yield c

def test_health(client):
    rv = client.get('/health')
    assert rv.status_code == 200
    assert rv.get_json().get('status') == 'ok'

def test_artifacts_store_and_retrieve(client, tmp_path):
    payload = {'k': 'v'}
    r = client.post('/artifacts', json=payload)
    assert r.status_code == 201
    r2 = client.get('/artifacts')
    assert isinstance(r2.get_json(), list)
