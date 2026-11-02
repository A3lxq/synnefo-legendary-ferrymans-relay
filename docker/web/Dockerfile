FROM debian:12-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq \
        python3 python3-venv python3-pip supervisor gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/supervisor /opt/shared /opt/web/downloads /opt/web/secret

RUN python3 -m venv /opt/venv
COPY docker/web/requirements.txt /opt/app/requirements.txt
RUN /opt/venv/bin/pip install -q --no-cache-dir --retries 10 --timeout 120 \
        -r /opt/app/requirements.txt

# Compile the relay-client binary players download and reverse-engineer.
COPY docker/client-src/relay_client.c /opt/build/relay_client.c
# Deliberately NOT stripped -- symbol names (main, decode_token, etc.)
# stay intact so `strings`/`objdump -d` are approachable for "light"
# reverse engineering, not an unpacking exercise.
RUN gcc -O0 -g0 -o /opt/web/downloads/relay-client /opt/build/relay_client.c && \
    rm -rf /opt/build

COPY docker/generate_flags.py /opt/shared/generate_flags.py
COPY docker/web/app.py /opt/app/app.py
COPY docker/web/entrypoint.sh /opt/entrypoint.sh
COPY docker/web/supervisord.conf /etc/supervisor/conf.d/ctf.conf
RUN chmod +x /opt/entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["/opt/entrypoint.sh"]
