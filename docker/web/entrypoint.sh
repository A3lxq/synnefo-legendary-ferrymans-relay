#!/bin/bash
set -euo pipefail

: "${CTF_SECRET:?CTF_SECRET must be set}"
export CTF_SECRET

mkdir -p /var/log/supervisor /opt/web/secret

# flag8: never exposed via any HTTP route on this container at all --
# reachable only via `docker exec` into THIS container, using the
# docker.sock access discovered inside vault (the "sibling container
# compromise" lesson).
/opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$CTF_SECRET', 8))" > /opt/web/secret/flag8.txt
chmod 644 /opt/web/secret/flag8.txt

echo "[entrypoint] Web ready."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ctf.conf
