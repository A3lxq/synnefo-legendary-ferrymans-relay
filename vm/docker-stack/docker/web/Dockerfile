FROM debian:12-slim AS builder
RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*
# Compile the relay-client binary players download and reverse-engineer,
# in a throwaway build stage -- gcc/libc6-dev never end up in the final
# image, only the compiled binary does.
COPY docker/client-src/relay_client.c /opt/build/relay_client.c
# Deliberately NOT stripped -- symbol names (main, decode_token, etc.)
# stay intact so `strings`/`objdump -d` are approachable for "light"
# reverse engineering, not an unpacking exercise.
RUN gcc -O0 -g0 -o /opt/relay-client /opt/build/relay_client.c

FROM debian:12-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq \
        python3 python3-venv python3-pip supervisor \
        openssh-server curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /opt/shared /opt/web/downloads /opt/web/secret

# relay_ops: the player's real foothold on this host, reusing the same
# password the /login page already discloses (a realistic password-
# reuse lesson) -- this is how a player actually runs the downloaded
# relay-client binary against relay over the internal network, since
# relay's own port is never published. Deliberately unprivileged: it
# must NOT be able to read flag8.txt on its own (see entrypoint.sh).
RUN useradd -m -s /bin/bash relay_ops

RUN python3 -m venv /opt/venv
COPY docker/web/requirements.txt /opt/app/requirements.txt
RUN /opt/venv/bin/pip install -q --no-cache-dir --retries 10 --timeout 120 \
        -r /opt/app/requirements.txt

COPY --from=builder /opt/relay-client /opt/web/downloads/relay-client

COPY docker/generate_flags.py /opt/shared/generate_flags.py
COPY docker/web/app.py /opt/app/app.py
COPY docker/web/entrypoint.sh /opt/entrypoint.sh
COPY docker/web/supervisord.conf /etc/supervisor/conf.d/ctf.conf
RUN chmod +x /opt/entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["/opt/entrypoint.sh"]
