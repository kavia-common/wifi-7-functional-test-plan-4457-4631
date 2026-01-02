import os
from app.main import app

def test_root():
    # use Flask test client
    c = app.test_client()
    r = c.get('/')
    assert r.status_code == 200
    assert r.get_json().get('status') == 'ok'
