import sqlite3, os
PKG_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB_PATH = os.path.join(PKG_ROOT, 'data', 'coredoc.db')

def get_conn(path=None):
    db = path or DB_PATH
    os.makedirs(os.path.dirname(db), exist_ok=True)
    return sqlite3.connect(db, check_same_thread=False)
