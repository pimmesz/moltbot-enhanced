# ============================================================================
# Moltbot Unraid - Single-stage build (installs from npm)
# ============================================================================

FROM node:24-slim

# --------------------------------------------------------------------------
# Unraid defaults
# --------------------------------------------------------------------------
ENV PUID=99
ENV PGID=100
ENV TZ=UTC

ENV MOLTBOT_PORT=18789
ENV MOLTBOT_BIND=lan

# --------------------------------------------------------------------------
# Runtime dependencies
# --------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      gosu \
      tzdata \
      bash \
      curl \
      ca-certificates \
      passwd \
      procps \
      chromium \
      python3 \
      openssl \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------
# Install Moltbot from npm (still published as 'clawdbot' during rename transition)
# --------------------------------------------------------------------------
RUN npm install -g clawdbot@latest && \
    clawdbot --version && \
    npm cache clean --force && \
    rm -rf /root/.npm

# --------------------------------------------------------------------------
# Filesystem layout
# --------------------------------------------------------------------------
WORKDIR /

RUN mkdir -p /config /tmp/moltbot && \
    chmod 1777 /tmp /tmp/moltbot

# --------------------------------------------------------------------------
# Install entrypoint + wrapper
# --------------------------------------------------------------------------
COPY start.sh /start.sh
COPY moltbot-wrapper.sh /usr/local/bin/moltbot-wrapper
COPY healthcheck.sh /healthcheck.sh

RUN chmod +x \
      /start.sh \
      /healthcheck.sh \
      /usr/local/bin/moltbot-wrapper

# --------------------------------------------------------------------------
# Enforce wrapper as the ONLY Moltbot entrypoint
# --------------------------------------------------------------------------
RUN mv /usr/local/bin/clawdbot /usr/local/bin/moltbot-real && \
    ln -sf /usr/local/bin/moltbot-wrapper /usr/local/bin/moltbot && \
    ln -sf /usr/local/bin/moltbot-wrapper /usr/local/bin/clawdbot && \
    chmod 750 /usr/local/bin/moltbot-real

# --------------------------------------------------------------------------
# Metadata
# --------------------------------------------------------------------------
LABEL maintainer="pimmesz"
LABEL org.opencontainers.image.title="Moltbot Unraid"
LABEL org.opencontainers.image.description="Moltbot AI agent gateway for Unraid"
LABEL org.opencontainers.image.authors="pimmesz"
LABEL org.opencontainers.image.source="https://github.com/pimmesz/moltbot-unraid"

# --------------------------------------------------------------------------
# Networking & persistence
# --------------------------------------------------------------------------
EXPOSE 18789
VOLUME ["/config"]

# --------------------------------------------------------------------------
# Healthcheck (runs via wrapper environment)
# --------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD HOME=/config /healthcheck.sh

# --------------------------------------------------------------------------
# Entrypoint & default command
# --------------------------------------------------------------------------
ENTRYPOINT ["/start.sh"]
CMD ["gateway"]