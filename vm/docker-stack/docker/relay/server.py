"""
Ferryman Relay server. Raw TCP, port 9099 (internal-only -- never
published, reachable only by pivoting through the web container).
Protocol/auth token: reverse-engineered by players from the
relay-client binary (see docker/client-src/relay_client.c and the
analogous obfuscation here).
"""
import os
import socketserver
import subprocess
import sys

sys.path.insert(0, "/opt/shared")
from generate_flags import flag_for  # noqa: E402

SECRET = os.environ["CTF_SECRET"]
MAGIC = "FERRY1"
TOKEN = "FR-9f2c-RELAY"  # matches relay_client.c's XOR-decoded value
SHARED_DIR = "/shared"


def flag(n):
    return flag_for(SECRET, n)


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        try:
            line = self.rfile.readline().decode(errors="replace").strip()
        except Exception:
            return
        # maxsplit=3: a RUN command's own payload can legitimately
        # contain "|" (e.g. shell pipes) -- only the first three
        # delimiters are ever protocol framing, everything after the
        # third one is the verbatim command.
        parts = line.split("|", 3)
        if not parts or parts[0] != MAGIC:
            self.wfile.write(b"ERR bad magic\n")
            return

        cmd = parts[1] if len(parts) > 1 else ""

        if cmd == "VERSION":
            self.wfile.write(f"relay v1.2 - {flag(3)}\n".encode())

        elif cmd == "STATUS":
            token = parts[2] if len(parts) > 2 else ""
            if token == TOKEN:
                self.wfile.write(f"status: ok - {flag(4)}\n".encode())
            else:
                self.wfile.write(b"ERR bad token\n")

        elif cmd == "RUN":
            token = parts[2] if len(parts) > 2 else ""
            runcmd = parts[3] if len(parts) > 3 else ""
            if token != TOKEN:
                self.wfile.write(b"ERR bad token\n")
                return
            # INTENTIONALLY VULNERABLE: the entire point of this
            # protocol command is arbitrary command execution once
            # authenticated -- that's the "custom protocol" RCE lesson.
            try:
                out = subprocess.run(runcmd, shell=True, capture_output=True, timeout=5, text=True)
                self.wfile.write((out.stdout + out.stderr).encode())
            except Exception as e:
                self.wfile.write(f"error: {e}\n".encode())

        else:
            self.wfile.write(b"ERR unknown command\n")


if __name__ == "__main__":
    os.makedirs(SHARED_DIR, exist_ok=True)
    with socketserver.ThreadingTCPServer(("0.0.0.0", 9099), Handler) as server:
        server.serve_forever()
