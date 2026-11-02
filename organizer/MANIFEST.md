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
- `docker-compose.yml` mounts the REAL host's `/var/run/docker.sock`
  into vault. This is the box's whole final act, and also means running
  this box hands a player real control of whatever machine runs it —
  **never deploy this on shared/multi-tenant infrastructure.**
- Debian's packaged `docker.io` CLI negotiates an old API version many
  real daemons now reject ("client version ... is too old"). Fixed via
  `DOCKER_API_VERSION=1.44` in the poller's own supervisord environment
  (so every payload it executes inherits it); a player landing a more
  direct shell in vault by some other means would need to set this
  themselves too (mentioned in `docs/hints.md`).
- `host-secrets` volume is deliberately never mounted into web, relay,
  or vault — only reachable by using the escaped Docker socket to
  create a brand-new container that mounts it.
