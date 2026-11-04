# Organizer manifest — Ferryman's Relay (Legendary)

Keep this file (and this whole `organizer/` directory) off any
player-facing host. Flag *values* are never written here — re-derive
them from the deployment's `CTF_SECRET`
(HMAC-SHA256("legendary-ferrymans-relay:N", secret), first 10 hex chars,
wrapped `HLC{...}`).

Three hosts: **Web** (published), **Relay** (custom TCP protocol,
internal-only), **Vault** (internal-only, the real Docker socket
mounted in). A fourth, one-shot **init** service populates a named
volume (`halcyon-legendary-host-secrets`) that nothing else in the box
mounts, then exits — not part of the attack surface.

**Shipped as ONE native OVA, not a separate Docker deployment.**
Docker Engine runs *inside* that one VM as this box's deliberately-
vulnerable target (installed by cloud-init, the compose stack started
by a systemd unit on boot) — not as the box's own deployment
mechanism. A player just imports and powers on the OVA, same as every
other box in this series. This means the docker.sock escape in stages
8-9 reaches that one VM's own Docker engine, not any shared host —
contained to the player's own disposable VM. See `vm/` for the build.

**Design gap fixed during the native rebuild** (not a Docker-vs-native
issue, just a real bug found then): the original design had no actual
way for a player to reach Relay's port 9099 at all (never published,
no shell anywhere) — `tests/solve.sh` papered over this with
`docker exec`/`docker cp`, which isn't something a real player could
do. Fixed by adding a real `relay_ops` SSH account on Web (port 2206),
reusing the same password the `/login` page discloses (a believable
password-reuse lesson) — the player logs in, re-downloads
`relay-client` from `localhost:5000` (Web's own internal port, not the
externally-mapped one), and runs it from there, able to reach Relay
over the stack's own internal network. **flag8.txt had to be tightened
from `chmod 644` to `chmod 600` + `chown root:root`** once Web got a
real shell — otherwise the new `relay_ops` account could just `cat` it
directly, skipping the entire Vault/docker.sock chain.

| # | Host | Difficulty | Concept taught | Primary tool(s) | Where it lives |
|---|---|---|---|---|---|
| 1 | Web | Easy | Reading page source | curl/browser | HTML comment on `/` |
| 2 | Web | Easy | Default/weak credentials | curl/browser | `relay_ops`/`ferryman2024` on `/login` |
| 3 | Relay | Medium | Light reverse engineering of a real ELF binary | `strings`, `objdump -d` | `relay-client`'s `VERSION` command (no auth) |
| 4 | Relay | Medium | Recovering an XOR-obfuscated secret from disassembly | `objdump -d decode_token`, manual XOR | `STATUS` command |
| 5 | Relay | Hard | Custom-protocol RCE | the reversed protocol + `RUN` | `/opt/relay/secret/flag5.txt` + `relay.conf`'s passphrase |
| 6/7 | Vault | Hard | Container escape via a shared volume job queue | drop a job into `/shared/task.sh`, wait for vault's poller | `/opt/vault/secret/flag6.txt`, `flag7.txt` |
| 8 | Vault→Web | Legendary | Chained privesc #1: Docker-socket sibling-container compromise | `docker exec` via the mounted `docker.sock` | Web's `/opt/web/secret/flag8.txt` (never HTTP-exposed) |
| 9 | Vault→new | Legendary | Chained privesc #2: spin up a fresh container to reach an otherwise-unmounted volume | `docker run -v halcyon-legendary-host-secrets:/data` | that volume's `flag9.txt` |
| 10 | — | Capstone | Combining a passphrase found early with evidence found last | `flagcrypto.py` (ships to players) | that volume's `dossier.enc` |

## Honeypots (never flag-shaped, cost time only)
- Web `/admin` — a plausible path, 501, nothing behind it.
- `relay-client`'s `DECOY_TOKEN` constant (`FR-0001-LEGACY`) — a
  plaintext string shaped like the real auth token, visible in plain
  `strings` output, genuinely unused and rejected by the server. The
  real token is XOR'd; that difference is the actual tell.

## Fixed design constants (intentional, not secret-derived)
- Protocol: `MAGIC="FERRY1"`, commands `VERSION` / `STATUS|<token>` /
  `RUN|<token>|<cmd>`, port 9099. Auth token `FR-9f2c-RELAY`, stored
  XOR'd with `0x5A` in the client binary.
- `docker-compose.yml`'s server-side parser uses `split("|", 3)` (not a
  plain `split("|")`) specifically so a `RUN` command's own payload can
  contain `|` (shell pipes) without corrupting the protocol framing —
  hit and fixed during testing; verify this wasn't quietly reverted.
- Vault's poller (`docker/vault/poller.sh`) executes anything dropped at
  `/shared/task.sh` with zero validation — the entire container-escape
  mechanism.
- `docker-compose.yml` mounts `/var/run/docker.sock` into vault. This
  is the box's whole final act. In the shipped OVA, that socket
  belongs to the Docker engine running inside the player's own VM, so
  the escape is contained there — same as any other container-escape
  lab. If you ever run this `docker-stack/` directly on bare metal
  instead of inside the VM, that stops being true: it mounts whatever
  machine actually runs `docker compose up`, so never do that on
  shared/multi-tenant infrastructure.
- `alpine` is pre-pulled during provisioning (`docker pull alpine`)
  so flag 9's throwaway container never needs live internet access
  during actual play -- this box is meant to run fully isolated.
- Debian's packaged `docker.io` CLI negotiates an old API version many
  real daemons now reject ("client version ... is too old"). Fixed via
  `DOCKER_API_VERSION=1.44` in the poller's own supervisord environment
  (so every payload it executes inherits it); a player landing a more
  direct shell in vault by some other means would need to set this
  themselves too (mentioned in `docs/hints.md`).
- `host-secrets` volume is deliberately never mounted into web, relay,
  or vault — only reachable by using the escaped Docker socket to
  create a brand-new container that mounts it.
