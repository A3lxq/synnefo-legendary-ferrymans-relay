# Case File 6 (Legendary) — Ferryman's Relay

Part of **The Halcyon Protocol** CTF series. This box stands alone — you do
not need any other box in the series to play it.

> See [`STORY.md`](STORY.md) for the full case file.

## ⚠️ Before you run this one

This box's final stages mount the **real Docker socket** of whatever
machine runs it into one of its containers — that's the intended
"container escape" lesson, not a mistake. Playing it to completion means
your player ends up with genuine control over that machine's Docker
daemon (able to start/stop/inspect any container, read any named
volume, etc.).

- **Only run this on your own isolated lab machine or VM** — never on
  shared infrastructure, a CI runner, or anything you don't fully
  control.
- If you'd rather not grant that, don't run this box, or only play
  flags 1–7 (everything up to and including the container escape into
  Vault, before Vault's Docker-socket access comes into play).

## What this is

**Three hosts**: a public Web front door, a Relay speaking a custom TCP
protocol (internal-only), and a Vault (internal-only, with real Docker
socket access). 10 flags, no decoys, climbing from a web login through
reverse-engineering a real compiled binary, a custom protocol, remote
code execution, a container escape, and finally a genuine Docker-socket
privilege escalation.

**This machine is intentionally vulnerable. Run it only on an isolated
network**, per the warning above.

## Status

This box ships as a VM appliance (OVA) — see the `vm/` directory once it's
built. There is no Docker build in this repo (an earlier Docker build was
removed; a Docker version may be added back separately).

## Flag format

`HLC{xxxxxxxxxx}` — submit exactly as found.

## Rules

- No decoy flags: everything matching the flag format is real and counts.
- Some things in this box are honeypots — red herrings that cost you time,
  not flags.
- Don't attack this box over a shared or public network.

## More

- [`STORY.md`](STORY.md) — the in-universe case file
- [`docs/hints.md`](docs/hints.md) — progressive hints
- [`docs/tools.md`](docs/tools.md) — what each tool is for
- [`docs/writeup/WRITEUP.md`](docs/writeup/WRITEUP.md) — full spoiler walkthrough
- [`flags/generate_flags.py`](flags/generate_flags.py) — the per-deployment flag derivation scheme, used by `organizer/verify.py`
