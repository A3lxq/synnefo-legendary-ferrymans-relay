#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f .env ]; then
    echo "No .env found — generating one with a fresh CTF_SECRET."
    echo "CTF_SECRET=$(openssl rand -hex 32)" > .env
fi
docker compose up -d --build
echo
echo "Web is up: http://localhost:8006"
echo "Relay and Vault are internal-only — not reachable from the host."
echo
echo "NOTE: vault mounts the real Docker socket from this host, as part"
echo "of the box's intended container-escape lesson. Only run this box"
echo "on a machine you'd be comfortable giving a player full Docker"
echo "control over -- never on shared/multi-tenant infrastructure."
