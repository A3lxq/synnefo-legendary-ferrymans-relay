#!/bin/bash
set -euo pipefail

: "${CTF_SECRET:?CTF_SECRET must be set}"
export CTF_SECRET

mkdir -p /var/log/supervisor /opt/web/secret

# flag8: NOT readable by relay_ops (the player's own foothold account
# here) -- root-owned, 600. Reachable only via `docker exec` (or an
# equivalent root shell) into THIS container, using the docker.sock
# access discovered inside vault (the "sibling container compromise"
# lesson). This is the whole point: relay_ops gets you IN, not root.
/opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$CTF_SECRET', 8))" > /opt/web/secret/flag8.txt
chown root:root /opt/web/secret/flag8.txt
chmod 600 /opt/web/secret/flag8.txt

# relay_ops: real foothold account, password reused from /login.
RELAY_OPS_PASSWORD="ferryman2024"
echo "relay_ops:$RELAY_OPS_PASSWORD" | chpasswd
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/90-relay_ops-password-auth.conf <<'EOF'
Match User relay_ops
    PasswordAuthentication yes
EOF
ssh-keygen -A >/dev/null 2>&1 || true

echo "[entrypoint] Web ready."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ctf.conf
