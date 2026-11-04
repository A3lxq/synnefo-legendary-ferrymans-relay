# VM / OVA — Ferryman's Relay

Guest OS: **Ubuntu Server 24.04 LTS** (official cloud image), via
QEMU/KVM + cloud-init (NoCloud). **One VM** — unlike this series'
other multi-host boxes, Docker Engine runs *inside* this single VM,
hosting the box's own three containers (web, relay, vault) exactly as
originally designed. Docker is this box's deliberately-vulnerable
target, not its deployment mechanism: you just import and power on
the OVA like every other box in this series, and the docker-compose
stack inside starts itself automatically via a systemd unit.

This matters for the box's final act: the "container escape" and
Docker-socket privilege escalation stages reach *this VM's own*
Docker engine. A full escape only ever hands a player control of
their own disposable VM — contained the same way any other
container-escape lab is contained.

## Using the pre-built OVA

Download the `.ova` from this repo's Releases page, then File > Import
Appliance in VirtualBox (or Open in VMware Workstation/Fusion). Power
it on and wait a few minutes — building and starting the internal
docker-compose stack happens automatically on first boot and can take
a while depending on your hardware. Once up:

- Web app: the VM's forwarded port 8006 (NAT adapter 1 — check
  VirtualBox's port-forwarding rules for the actual mapped port on
  your host).
- The real player foothold is SSH to the **web container itself**
  (not the VM) on the VM's forwarded port 2206, using the same
  username/password the `/login` page discloses.

**This is an intentionally vulnerable machine, and its final stages
are a real Docker-socket escape. Import it only on an isolated
network/host.**

## Build from source

```
cd vm
# put ubuntu-24.04-server-cloudimg-amd64.img in images/ first
# put your own ed25519 keypair in keys/ctfbuilder_ed25519[.pub],
# and reference the .pub in cloud-init/user-data.yaml
# generate a release secret: openssl rand -hex 32 > ../organizer/release-secret.txt
./scripts/create-disk.sh
./scripts/boot-vm.sh      # wait a few minutes for first boot + cloud-init
./scripts/provision.sh    # copies docker-stack/, builds + starts the compose stack
./scripts/verify.sh       # proves all 10 flags before you export anything
./scripts/export-vm.sh
./scripts/export-ova.sh
```

`docker-stack/` holds the actual docker-compose project (Dockerfiles,
app source, `docker-compose.yml`) — committed as real files, not an
embedded blob, so it's readable and diffable like everything else in
this repo. `provision.sh` copies it to `/opt/legendary` on the guest
and `remote-provision.sh` builds and starts it there.

## Build note: the SSH foothold (a real design gap, fixed here)

The original design had no actual way for a player to reach `relay`'s
custom TCP port at all — it's never published, and there was no shell
anywhere. A `relay_ops` SSH account was added to the web container
(port 2206), reusing the same password the `/login` page already
discloses, so a player has a real shell that can reach `relay` over
the stack's own internal network. `flag8.txt` had to move from
`chmod 644` to `chmod 600` + `chown root:root` accordingly — otherwise
`relay_ops` could just read it directly, skipping the entire
Vault/docker.sock chain. See `organizer/MANIFEST.md` for the full
writeup of this fix.

## Build note: pre-pulling `alpine`

`remote-provision.sh` runs `docker pull alpine` once, right after
starting the stack. Flag 9 spins up a fresh `alpine` container via the
escaped docker.sock — without pre-pulling, that first pull can be slow
enough under emulation to blow past a tight polling window, and more
importantly this box is meant to run fully isolated, so flag 9 must
not depend on live internet access during actual play.
