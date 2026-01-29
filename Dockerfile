# ============================================================================
# Stage 1: Build Moltbot from source
# ============================================================================

FROM node:24-slim AS builder

SHELL ["/bin/bash", "-lc"]
WORKDIR /build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      python3 \
      make \
      g++ \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm@latest

# Clone Moltbot source
RUN git clone --depth 1 https://github.com/moltbot/moltbot.git .

# Install deps with pnpm cache
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# Build Moltbot + pack the actual moltbot package (not the monorepo root)
RUN pnpm build && \
    pnpm ui:build && \
    mkdir -p /build/pkg && \
    pnpm -r --filter "moltbot" pack --pack-destination /build/pkg && \
    ls -la /build/pkg && \
    PKG="$(ls -1 /build/pkg/*.tgz | head -n 1)" && \
    cp "$PKG" /build/moltbot.tgz && \
    echo "== packed contents (bin sanity) ==" && \
    tar -tf /build/moltbot.tgz | sed -n '1,120p'


# ============================================================================
# Stage 2: Runtime image (Unraid-friendly)
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
      git \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------
# Install Moltbot package
# --------------------------------------------------------------------------
COPY --from=builder /build/moltbot.tgz /tmp/moltbot.tgz

RUN npm install -g /tmp/moltbot.tgz && \
    echo "=== Checking moltbot package structure ===" && \
    ls -la /usr/local/lib/node_modules/moltbot/ && \
    echo "=== Checking moltbot bin directory ===" && \
    ls -la /usr/local/lib/node_modules/moltbot/bin/ 2>/dev/null || echo "No bin directory" && \
    echo "=== Checking moltbot dist directory ===" && \
    ls -la /usr/local/lib/node_modules/moltbot/dist/ 2>/dev/null || echo "No dist directory" && \
    echo "=== Creating manual symlink ===" && \
    if [ -f /usr/local/lib/node_modules/moltbot/bin/moltbot.js ]; then \
      ln -sf /usr/local/lib/node_modules/moltbot/bin/moltbot.js /usr/local/bin/moltbot; \
    elif [ -f /usr/local/lib/node_modules/moltbot/dist/cli.js ]; then \
      ln -sf /usr/local/lib/node_modules/moltbot/dist/cli.js /usr/local/bin/moltbot; \
    else \
      echo "ERROR: Cannot find moltbot binary" && exit 1; \
    fi && \
    chmod +x /usr/local/bin/moltbot && \
    moltbot --version && \
    rm -f /tmp/moltbot.tgz && \
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
RUN mv /usr/local/bin/moltbot /usr/local/bin/moltbot-real
RUN ln -sf /usr/local/bin/moltbot-wrapper /usr/local/bin/moltbot
RUN chmod 750 /usr/local/bin/moltbot-real

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