FROM debian:12-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq \
        python3 supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/supervisor /opt/shared /shared

COPY docker/generate_flags.py /opt/shared/generate_flags.py
COPY docker/relay/server.py /opt/app/server.py
COPY docker/relay/entrypoint.sh /opt/entrypoint.sh
COPY docker/relay/supervisord.conf /etc/supervisor/conf.d/ctf.conf
RUN chmod +x /opt/entrypoint.sh

EXPOSE 9099
# Never published in docker-compose.yml -- internal-only on purpose.

ENTRYPOINT ["/opt/entrypoint.sh"]
