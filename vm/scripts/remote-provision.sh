#!/usr/bin/env bash
# remote-provision.sh — deploys the Ferryman's Relay CTF box onto an
# already-booted Ubuntu 24.04 guest (run over SSH as ctfbuilder, with
# sudo), AFTER vm/docker-stack/ has already been copied to
# /opt/legendary on the guest (provision.sh does that). This box's
# own top-tier lesson IS a real Docker-socket escape, so Docker Engine
# (already installed by cloud-init) runs the original docker-compose
# stack (web + relay + vault) INSIDE this VM as the deliberately-
# vulnerable target -- Docker is not this box's deployment mechanism;
# the player only ever imports and powers on the OVA. Public script,
# so never hardcode the release secret here -- it must only ever
# arrive via the SSH session's own environment.
set -euo pipefail

: "${RELEASE_SECRET:?RELEASE_SECRET must be passed in (never hardcode it here -- this script is public)}"

echo "== Writing .env (release secret -- lives only on this VM's disk, never committed) =="
sudo tee /opt/legendary/.env >/dev/null <<EOF
CTF_SECRET=$RELEASE_SECRET
EOF
sudo chmod 600 /opt/legendary/.env

echo "== Building the stack's images (this takes a while the first time) =="
cd /opt/legendary
sudo docker compose build

echo "== Starting the stack =="
sudo docker compose up -d

echo "== Pre-pulling alpine (flag 9's throwaway container image) =="
# Cached now so flag 9 never needs live internet access during actual
# play -- this box is meant to run fully isolated, and the first-pull
# delay alone can exceed a tight poll window under slow/emulated
# hardware anyway.
sudo docker pull alpine

echo "== Installing a systemd unit so the stack survives reboots =="
sudo tee /etc/systemd/system/legendary-stack.service >/dev/null <<'EOF'
[Unit]
Description=Ferryman's Relay docker-compose stack
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/legendary
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable legendary-stack.service

echo "[remote-provision] Ferryman's Relay ready."
