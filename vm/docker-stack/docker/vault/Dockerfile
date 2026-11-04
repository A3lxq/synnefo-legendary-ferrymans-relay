FROM debian:12-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq \
        python3 python3-venv python3-pip supervisor \
        docker.io \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/supervisor /opt/shared /shared /opt/vault/secret

RUN python3 -m venv /opt/venv
RUN /opt/venv/bin/pip install -q --no-cache-dir --retries 10 --timeout 120 cryptography==43.0.3

COPY docker/generate_flags.py /opt/shared/generate_flags.py
COPY docker/flagcrypto.py /opt/shared/flagcrypto.py
COPY docker/vault/poller.sh /opt/poller.sh
COPY docker/vault/entrypoint.sh /opt/entrypoint.sh
COPY docker/vault/init_hostsecrets.sh /opt/init_hostsecrets.sh
COPY docker/vault/supervisord.conf /etc/supervisor/conf.d/ctf.conf
RUN chmod +x /opt/entrypoint.sh /opt/poller.sh /opt/init_hostsecrets.sh

# No published ports at all -- vault is reached only by dropping a job
# into the shared volume from relay's RCE (docker-compose.yml).
ENTRYPOINT ["/opt/entrypoint.sh"]
