#!/bin/bash
# One-shot: populates the "host-secrets" named volume, representing
# what a real host administrator would have placed there -- never
# mounted into relay, web, or vault directly. The ONLY way a player
# reaches this is by using vault's docker.sock access to spin up their
# own throwaway container that mounts this same named volume.
set -euo pipefail
: "${CTF_SECRET:?CTF_SECRET must be set}"

VENV=/opt/venv
getflag() { $VENV/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$CTF_SECRET', $1))"; }
getsecret() { $VENV/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import secret_for; print(secret_for('$CTF_SECRET', '$1'))"; }

mkdir -p /hostsecrets
getflag 9 > /hostsecrets/flag9.txt

DOSSIER_PW=$(getsecret dossier_password)
F10=$(getflag 10)
echo -n "$F10" > /tmp/flag10_plain.txt
$VENV/bin/python3 /opt/shared/flagcrypto.py encrypt "$DOSSIER_PW" /tmp/flag10_plain.txt /hostsecrets/dossier.enc
rm -f /tmp/flag10_plain.txt

chmod 644 /hostsecrets/flag9.txt /hostsecrets/dossier.enc
echo "[init] host-secrets populated."
