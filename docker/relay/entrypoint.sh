#!/bin/bash
set -euo pipefail

: "${CTF_SECRET:?CTF_SECRET must be set}"
export CTF_SECRET

mkdir -p /var/log/supervisor /opt/relay/secret /shared

getflag() { python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$CTF_SECRET', $1))"; }
getsecret() { python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import secret_for; print(secret_for('$CTF_SECRET', '$1'))"; }

# Reachable only via the RUN command's RCE, not any plain protocol read.
getflag 5 > /opt/relay/secret/flag5.txt
DOSSIER_PW=$(getsecret dossier_password)
cat > /opt/relay/secret/relay.conf <<EOF
# internal config, never served by the protocol itself
emergency_recovery_passphrase=$DOSSIER_PW
EOF
chmod 600 /opt/relay/secret/*.txt /opt/relay/secret/relay.conf

echo "[entrypoint] Relay ready."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ctf.conf
