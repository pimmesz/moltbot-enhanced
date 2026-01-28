FROM node:24-slim

ENV PUID=99
ENV PGID=100
ENV TZ=UTC
ENV MOLTBOT_PORT=18789
ENV MOLTBOT_BIND=lan

# Install essential runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gosu tzdata git curl ca-certificates procps \
    python3 python3-pip python3-venv \
    ffmpeg sox sqlite3 postgresql-client jq wget unzip && \
    rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir \
    requests beautifulsoup4 selenium playwright \
    pandas numpy pillow pyyaml python-dotenv \
    sqlalchemy psycopg2-binary redis \
    paho-mqtt zeroconf pytz python-dateutil cryptography

# Install Playwright browsers
RUN python3 -m playwright install chromium firefox webkit --with-deps

# Install moltbot from npm registry (published package)
RUN npm install -g moltbot

WORKDIR /

# Create directories
RUN mkdir -p /config /tmp/moltbot && chmod 1777 /tmp

# Copy entrypoint scripts
COPY start.sh /start.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /start.sh /healthcheck.sh

EXPOSE 18789
VOLUME ["/config"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh

ENTRYPOINT ["/start.sh"]
CMD ["gateway"]
