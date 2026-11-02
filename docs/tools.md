# Tools you'll use in this box

| Tool | What it's for here |
|---|---|
| curl / browser | Recon, login, downloading the client binary. |
| `strings` | First pass over the downloaded `relay-client` binary — the protocol's magic header and command names are plain text; a decoy "token" is too (read it carefully). |
| `objdump -d` | Disassemble `relay-client` to find `decode_token`'s XOR routine and key, and to recover the real auth token. |
| `nc` / the `relay-client` binary itself | Speak the reversed protocol to the relay service once you know its magic/commands/token. |
| Base64 encoding | Smuggling multi-step shell commands (that themselves contain pipes, quotes, etc.) through several layers of this box's own quoting without them colliding. |
| `docker exec` / `docker run` (once you have Docker-socket access) | The final privilege escalation — full control over sibling containers and the ability to create new ones with arbitrary mounts. |
| `docker/flagcrypto.py` (ships with this repo) | Decrypt the final dossier once you have its passphrase. |
