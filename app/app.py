"""Small notes REST API (Flask + SQLite)."""
import os
import sqlite3
from flask import Flask, request, jsonify, g

# config from env, no hard-coded secrets
DATABASE = os.environ.get("DATABASE_PATH", "notes.db")
API_TOKEN = os.environ.get("API_TOKEN", "")
MAX_NOTE_LEN = 500

app = Flask(__name__)


def get_db():
    """Return a per-request SQLite connection."""
    if "db" not in g:
        g.db = sqlite3.connect(DATABASE)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(exception):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    """Create the notes table if it does not exist."""
    db = sqlite3.connect(DATABASE)
    db.execute(
        "CREATE TABLE IF NOT EXISTS notes ("
        " id INTEGER PRIMARY KEY AUTOINCREMENT,"
        " content TEXT NOT NULL"
        ")"
    )
    db.commit()
    db.close()


@app.after_request
def set_security_headers(response):
    # basic security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = "default-src 'none'"
    response.headers["Referrer-Policy"] = "no-referrer"
    return response


def require_token():
    # if no token is set, auth is off (fine for local use)
    if not API_TOKEN:
        return True
    header = request.headers.get("Authorization", "")
    return header == f"Bearer {API_TOKEN}"


@app.get("/healthz")
def healthz():
    """Health check endpoint (no auth)."""
    return jsonify(status="ok"), 200


@app.get("/notes")
def list_notes():
    if not require_token():
        return jsonify(error="unauthorized"), 401
    rows = get_db().execute("SELECT id, content FROM notes ORDER BY id").fetchall()
    return jsonify(notes=[dict(r) for r in rows]), 200


@app.post("/notes")
def create_note():
    if not require_token():
        return jsonify(error="unauthorized"), 401

    data = request.get_json(silent=True) or {}
    content = data.get("content")

    # validate input
    if not isinstance(content, str) or not content.strip():
        return jsonify(error="'content' must be a non-empty string"), 400
    if len(content) > MAX_NOTE_LEN:
        return jsonify(error=f"'content' exceeds {MAX_NOTE_LEN} characters"), 400

    # parameterized query (avoids SQL injection)
    db = get_db()
    cur = db.execute("INSERT INTO notes (content) VALUES (?)", (content,))
    db.commit()
    return jsonify(id=cur.lastrowid, content=content), 201


@app.get("/notes/<int:note_id>")
def get_note(note_id):
    if not require_token():
        return jsonify(error="unauthorized"), 401
    row = get_db().execute(
        "SELECT id, content FROM notes WHERE id = ?", (note_id,)
    ).fetchone()
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(dict(row)), 200


if __name__ == "__main__":
    # local dev only - the container uses gunicorn (see Dockerfile)
    init_db()
    app.run(
        host=os.environ.get("HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "8080")),
    )
