#!/usr/bin/env bash
# boot-vm.sh — starts this box's VM. Three forwarded ports:
#   2260 -> guest 22   (ctfbuilder, VM-level SSH, build/provisioning only)
#   8006 -> guest 8006 (the web app's published HTTP port, via the
#                        docker-compose stack running INSIDE this VM)
#   2206 -> guest 2206 (the web CONTAINER's own SSH -- the player's
#                        real foothold account, relay_ops, also via
#                        the docker-compose stack)
# Docker runs inside this VM as the deliberately-vulnerable target for
# this box's final act, not as this box's own deployment mechanism --
# the player only ever imports and powers the OVA on.
set -euo pipefail
cd "$(dirname "$0")/.."

DISK="disks/ferrymans-relay.qcow2"
SEED="seed/seed.img"
PIDFILE="disks/vm.pid"
MONITOR="disks/monitor.sock"
LOG="logs/vm-console.log"

if [ ! -f "$DISK" ] || [ ! -f "$SEED" ]; then
  echo "Missing $DISK or $SEED. Run ./scripts/create-disk.sh first." >&2
  exit 1
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "VM already running (pid $(cat "$PIDFILE"))." >&2
  exit 1
fi

mkdir -p logs

ACCEL="tcg"
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  ACCEL="kvm"
fi
echo "Using acceleration: $ACCEL"

qemu-system-x86_64 \
  -name ferrymans-relay \
  -machine type=q35,accel=$ACCEL \
  -cpu max \
  -m 2048 \
  -smp 2 \
  -drive file="$DISK",if=virtio,format=qcow2,discard=unmap,detect-zeroes=unmap \
  -drive file="$SEED",if=virtio,format=raw \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2260-:22,hostfwd=tcp:127.0.0.1:8006-:8006,hostfwd=tcp:127.0.0.1:2206-:2206 \
  -device virtio-net-pci,netdev=net0 \
  -display none \
  -serial file:"$LOG" \
  -monitor unix:"$MONITOR",server,nowait \
  -pidfile "$PIDFILE" \
  -daemonize

echo "VM starting (pid $(cat "$PIDFILE"))."
echo "Console log: vm/$LOG"
echo "SSH (build/provisioning only): ssh -i keys/ctfbuilder_ed25519 -p 2260 ctfbuilder@127.0.0.1"
echo "Web app (once provisioned): http://127.0.0.1:8006/"
echo "Web container SSH (player foothold, once provisioned): ssh -p 2206 relay_ops@127.0.0.1"
echo "Stop with: ./scripts/stop-vm.sh"
