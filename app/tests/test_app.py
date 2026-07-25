import os
import tempfile
import pytest

os.environ["DATABASE_PATH"] = os.path.join(tempfile.gettempdir(), "test_notes.db")

import app as app_module  # noqa: E402


@pytest.fixture()
def client():
    db = os.environ["DATABASE_PATH"]
    if os.path.exists(db):
        os.remove(db)
    app_module.init_db()
    app_module.app.config.update(TESTING=True)
    with app_module.app.test_client() as c:
        yield c


def test_healthz(client):
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.get_json()["status"] == "ok"


def test_create_and_get_note(client):
    res = client.post("/notes", json={"content": "hello world"})
    assert res.status_code == 201
    note_id = res.get_json()["id"]

    res = client.get(f"/notes/{note_id}")
    assert res.status_code == 200
    assert res.get_json()["content"] == "hello world"


def test_reject_empty_note(client):
    res = client.post("/notes", json={"content": "   "})
    assert res.status_code == 400


def test_reject_oversized_note(client):
    res = client.post("/notes", json={"content": "x" * 501})
    assert res.status_code == 400


def test_security_headers(client):
    res = client.get("/healthz")
    assert res.headers["X-Content-Type-Options"] == "nosniff"
    assert res.headers["X-Frame-Options"] == "DENY"
