#!/bin/bash
set -euo pipefail

: "${CTF_SECRET:?CTF_SECRET must be set}"
export CTF_SECRET

mkdir -p /var/log/supervisor /opt/vault/secret /shared

getflag() { /opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$CTF_SECRET', $1))"; }

getflag 6 > /opt/vault/secret/flag6.txt
getflag 7 > /opt/vault/secret/flag7.txt
chmod 600 /opt/vault/secret/*.txt

echo "[entrypoint] Vault ready."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ctf.conf
