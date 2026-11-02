"""
Ferryman Relay -- web front door. Flask, port 5000 (published).
"""
import os
import sys

from flask import Flask, request, Response, send_from_directory

sys.path.insert(0, "/opt/shared")
from generate_flags import flag_for  # noqa: E402

SECRET = os.environ["CTF_SECRET"]
app = Flask(__name__)


def flag(n):
    return flag_for(SECRET, n)


@app.route("/")
def index():
    return f"""<!DOCTYPE html><html><head><title>Ferryman Relay</title></head><body>
    <!-- {flag(1)} -->
    <h1>Halcyon Dynamics -- Ferryman Relay</h1>
    <p>Internal relay tooling portal. <a href="/login">Staff login</a> for
    the client tool download.</p>
    </body></html>"""


@app.route("/login", methods=["GET", "POST"])
def login():
    error = ""
    if request.method == "POST":
        if request.form.get("username") == "relay_ops" and request.form.get("password") == "ferryman2024":
            return f"""<h2>Welcome.</h2><p>{flag(2)}</p>
            <p>Download the internal client: <a href="/downloads/relay-client">relay-client</a></p>"""
        error = "Invalid credentials."
    return f"""<!DOCTYPE html><html><body><h2>Staff Login</h2>
    <p style="color:red">{error}</p>
    <form method="post">
      Username: <input name="username"><br>
      Password: <input name="password" type="password"><br>
      <button type="submit">Log in</button>
    </form></body></html>"""


@app.route("/admin")
def admin_decoy():
    # Honeypot: a plausible path, nothing behind it.
    return Response("Not implemented yet.\n", status=501)


@app.route("/downloads/relay-client")
def download_client():
    return send_from_directory("/opt/web/downloads", "relay-client", as_attachment=True)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
