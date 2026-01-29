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
    echo "=== Checking what was built ===" && \
    find /build -name "package.json" -type f | grep -E "packages/moltbot" | head -5 && \
    echo "=== Checking moltbot package directory ===" && \
    ls -la /build/packages/moltbot/ 2>/dev/null || ls -la /build/apps/moltbot/ 2>/dev/null || echo "Cannot find moltbot package" && \
    echo "=== Packing moltbot ===" && \
    mkdir -p /build/pkg && \
    pnpm -r --filter "moltbot" pack --pack-destination /build/pkg && \
    ls -la /build/pkg && \
    PKG="$(ls -1 /build/pkg/*.tgz | head -n 1)" && \
    cp "$PKG" /build/moltbot.tgz && \
    echo "=== Packed contents (first 200 lines) ===" && \
    tar -tf /build/moltbot.tgz | head -200


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
    echo "=== Checking installed package.json ===" && \
    cat /usr/local/lib/node_modules/moltbot/package.json && \
    echo "=== Full directory tree ===" && \
    find /usr/local/lib/node_modules/moltbot -type f | head -50 && \
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