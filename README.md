# Case File 6 (Legendary) — Ferryman's Relay

![banner](banner.jpeg)

Part of **The Halcyon Protocol** CTF series. This box stands alone — you do
not need any other box in the series to play it.

> See [`STORY.md`](STORY.md) for the full case file.

## ⚠️ Before you run this one

This box's final stages are a **real Docker-socket escape** — that's
the intended "container escape" lesson, not a mistake. Docker runs
*inside* the shipped VM as the deliberately-vulnerable target, not as
this box's deployment mechanism: you just import and power on the OVA
like every other box in this series. Playing this one to completion
means a player ends up with genuine control over the Docker daemon
running inside that one VM — contained to that disposable VM, the
same way any other container-escape lab is contained to its own box.

- **Only run this on an isolated network, same as every box in this
  series** — the escape reaches this VM's own Docker engine, nothing
  outside it.
- If you'd rather not build/run the full chain, flags 1–7 (everything
  up to and including the shared-volume escalation into Vault, before
  Vault's Docker-socket access comes into play) don't touch Docker at
  all.

## What this is

**One VM, three containers inside it**: a public Web front door, a
Relay speaking a custom TCP protocol (internal-only), and a Vault
(internal-only, with real Docker socket access to the VM's own engine).
10 flags, no decoys, climbing from a web login through reverse-
engineering a real compiled binary, a custom protocol, remote code
execution, a container escape, and finally a genuine Docker-socket
privilege escalation.

**This machine is intentionally vulnerable. Run it only on an isolated
network**, per the warning above.

## Running it

Download the `.ova` from this repo's [Releases](../../releases) page
and import it into VirtualBox (File > Import Appliance) or VMware
Workstation/Fusion (File > Open). It boots and sets itself up
automatically — nothing to configure. See [`vm/README.md`](vm/README.md)
for details and for rebuilding it from source.

## Flag format

`HLC{xxxxxxxxxx}` — submit exactly as found.

## Rules

- No decoy flags: everything matching the flag format is real and counts.
- Some things in this box are honeypots — red herrings that cost you time,
  not flags.
- Don't attack this box over a shared or public network.

## More

- [`vm/README.md`](vm/README.md) — build/import details, and why Docker
  runs inside this one VM instead of being this box's deployment tool
- [`STORY.md`](STORY.md) — the in-universe case file
- [`docs/hints.md`](docs/hints.md) — progressive hints
- [`docs/tools.md`](docs/tools.md) — what each tool is for
- [`docs/writeup/WRITEUP.md`](docs/writeup/WRITEUP.md) — full spoiler walkthrough
- [`flags/generate_flags.py`](flags/generate_flags.py) — the flag
  derivation scheme (HMAC-SHA256 of a release secret), used by
  `organizer/verify.py`. The OVA's flags are static (same release
  secret baked in at build time).
