#!/usr/bin/env bash
# export-vm.sh — snapshots the provisioned, verified state and
# flattens it into one standalone qcow2. Flags here are STATIC
# (release-secret-derived, baked in at provision time, same convention
# as The Forgotten Administrator's own VM) -- there's no per-deployment
# secret to wipe, unlike the abandoned Docker-in-VM approach.
set -euo pipefail
cd "$(dirname "$0")/.."

DISK="disks/ferrymans-relay.qcow2"
OUT_DIR="dist"
OUT_IMAGE="$OUT_DIR/ferrymans-relay-ctf.qcow2"

if [ ! -f "$DISK" ]; then
  echo "Missing $DISK. Build the VM first." >&2
  exit 1
fi

echo "== Stopping the VM (export needs the disk's write lock) =="
./scripts/stop-vm.sh

echo "== Snapshotting this verified, ready-to-play state =="
qemu-img snapshot -d clean-start "$DISK" 2>/dev/null || true
qemu-img snapshot -c clean-start "$DISK"

mkdir -p "$OUT_DIR"
echo "== Flattening the clean-start snapshot into a standalone image =="
rm -f "$OUT_IMAGE"
qemu-img convert -l clean-start -O qcow2 -c "$DISK" "$OUT_IMAGE"

echo "== Checksumming =="
(cd "$OUT_DIR" && sha256sum "$(basename "$OUT_IMAGE")" > SHA256SUMS)

echo "== Restarting the source VM (for any further work on this box) =="
./scripts/boot-vm.sh

echo
echo "Done. Next: ./scripts/export-ova.sh"
ls -lh "$OUT_DIR"
