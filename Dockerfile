# ============================================================================
# Moltbot Unraid - Single-stage build (installs from npm)
# ============================================================================

FROM node:24-slim

# --------------------------------------------------------------------------
# Unraid defaults & environment
# --------------------------------------------------------------------------
ENV PUID=99 \
    PGID=100 \
    TZ=UTC \
    MOLTBOT_PORT=18789 \
    MOLTBOT_BIND=lan \
    # Skip Chromium download during npm install (we install via apt)
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chromium-wrapper \
    # Container-safe Chromium environment
    CHROME_DEVEL_SANDBOX=0 \
    DISPLAY=:99

# --------------------------------------------------------------------------
# Runtime dependencies (single layer)
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
      # Enhanced font support for better web rendering
      fonts-liberation \
      fonts-noto \
      fonts-noto-cjk \
      fonts-noto-color-emoji \
      # Chromium runtime dependencies for headless mode
      libnss3 \
      libatk-bridge2.0-0 \
      libdrm2 \
      libxcomposite1 \
      libxrandr2 \
      libasound2 \
      python3 \
      python3-pip \
      openssl \
      git \
      jq \
      sqlite3 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /config /tmp/moltbot /dev/shm \
    && chmod 1777 /tmp /tmp/moltbot /dev/shm

# --------------------------------------------------------------------------
# Install Moltbot from npm (using beta until @latest tag is updated)
# Uses BuildKit cache mount for faster rebuilds
# --------------------------------------------------------------------------
RUN --mount=type=cache,target=/root/.npm \
    npm install -g moltbot@beta && \
    moltbot --version

# --------------------------------------------------------------------------
# Copy and setup entrypoint scripts
# --------------------------------------------------------------------------
COPY start.sh /start.sh
COPY moltbot-wrapper.sh /usr/local/bin/moltbot-wrapper
COPY healthcheck.sh /healthcheck.sh
COPY chromium-wrapper.sh /usr/local/bin/chromium-wrapper

RUN chmod +x /start.sh /healthcheck.sh /usr/local/bin/moltbot-wrapper /usr/local/bin/chromium-wrapper && \
    # Enforce wrapper as the ONLY Moltbot entrypoint
    mv /usr/local/bin/moltbot /usr/local/bin/moltbot-real && \
    ln -sf /usr/local/bin/moltbot-wrapper /usr/local/bin/moltbot && \
    ln -sf /usr/local/bin/moltbot-wrapper /usr/local/bin/clawdbot && \
    chmod 755 /usr/local/bin/moltbot-real && \
    # Create Chromium directories with proper permissions
    mkdir -p /tmp/chromium-crash /tmp/chromium-user-data && \
    chmod 1777 /tmp/chromium-crash /tmp/chromium-user-data

# --------------------------------------------------------------------------
# Metadata
# --------------------------------------------------------------------------
LABEL maintainer="pimmesz" \
      org.opencontainers.image.title="Moltbot Unraid" \
      org.opencontainers.image.description="Moltbot AI agent gateway for Unraid" \
      org.opencontainers.image.authors="pimmesz" \
      org.opencontainers.image.source="https://github.com/pimmesz/moltbot-enhanced"

EXPOSE 18789
VOLUME ["/config"]
WORKDIR /

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD HOME=/config /healthcheck.sh

ENTRYPOINT ["/start.sh"]
CMD ["gateway"]