# Multi-stage build for better caching
# Stage 1: Build moltbot from source
FROM node:24-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    python3 \
    make \
    g++ \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm@latest

# Clone and build moltbot
# Note: npm package (moltbot@latest) is incomplete (no binary), must build from source
RUN git clone --depth 1 https://github.com/moltbot/moltbot.git .

# Install dependencies with cache mount for faster rebuilds
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# Build and package
RUN pnpm build && \
    pnpm ui:build && \
    pnpm pack

# Stage 2: Runtime image
FROM node:24-slim

# Set environment variables for Unraid compatibility
# Unraid uses 99:100 (nobody:users) as default for Docker containers
ENV PUID=99
ENV PGID=100
ENV TZ=UTC

# Gateway configuration defaults
ENV MOLTBOT_PORT=18789
ENV MOLTBOT_BIND=lan

# Install runtime dependencies
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

# Copy and install the built package from builder stage
COPY --from=builder /build/moltbot-*.tgz /tmp/moltbot.tgz

RUN npm install -g /tmp/moltbot.tgz && \
    rm -f /tmp/moltbot.tgz && \
    npm cache clean --force && \
    rm -rf /root/.npm && \
    # Verify installation succeeded
    which moltbot || (echo "ERROR: moltbot binary not found" && exit 1) && \
    moltbot --version || (echo "ERROR: moltbot command failed" && exit 1)

WORKDIR /

# Create directories
# /config is the single persistent volume mount point
# /tmp/moltbot is for transient logs (will use tmpfs)
RUN mkdir -p /config /tmp/moltbot && \
    chmod 1777 /tmp

# Copy entrypoint, health check, and wrapper scripts
COPY start.sh /start.sh
COPY healthcheck.sh /healthcheck.sh
COPY moltbot-wrapper.sh /usr/local/bin/moltbot-wrapper
RUN chmod +x /start.sh /healthcheck.sh /usr/local/bin/moltbot-wrapper

# Replace moltbot binary with wrapper to ensure correct user for all commands
RUN mv /usr/local/bin/moltbot /usr/local/bin/moltbot-real && \
    ln -sf /usr/local/bin/moltbot-wrapper /usr/local/bin/moltbot

# Metadata labels for Docker Hub
LABEL maintainer="pimmesz"
LABEL org.opencontainers.image.title="Moltbot Unraid"
LABEL org.opencontainers.image.description="Moltbot AI agent gateway for Unraid - connects AI to messaging platforms"
LABEL org.opencontainers.image.authors="pimmesz"
LABEL org.opencontainers.image.url="https://github.com/pimmesz/moltbot-unraid"
LABEL org.opencontainers.image.source="https://github.com/pimmesz/moltbot-unraid"
LABEL org.opencontainers.image.documentation="https://github.com/pimmesz/moltbot-unraid/blob/main/README.md"

# Expose Gateway WebSocket port
EXPOSE 18789

# Declare volume for persistent data
VOLUME ["/config"]

# Health check using dedicated script
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh

# Use start.sh as entrypoint for PUID/PGID handling
ENTRYPOINT ["/start.sh"]

# Default command runs the gateway
# Can be overridden with: docker run ... moltbot-unraid <custom-command>
CMD ["gateway"]
