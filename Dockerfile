# Multi-platform base image (supports x86_64 and ARM64)
# Moltbot requires Node 24+ (package requirement: node >= 24)
# Using Debian-based image instead of Alpine for better native dependency support
FROM node:24-slim

# Set environment variables for Unraid compatibility
ENV PUID=1000
ENV PGID=1000
ENV TZ=UTC

# Moltbot-specific environment
# MOLTBOT_VERSION can be overridden at build time
ARG MOLTBOT_VERSION=latest
ENV MOLTBOT_VERSION=${MOLTBOT_VERSION}

# Gateway configuration defaults
ENV MOLTBOT_PORT=18789
ENV MOLTBOT_BIND=lan

# Install system dependencies
# - gosu: lightweight privilege dropping (Debian alternative to su-exec)
# - tzdata: timezone support
# - bash: shell compatibility
# - git: some moltbot features may need git
# - curl: health checks and downloads
# - python3, make, g++: needed for building native dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gosu \
    tzdata \
    bash \
    git \
    curl \
    ca-certificates \
    python3 \
    make \
    g++ && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm (moltbot requires pnpm >= 10)
RUN npm install -g pnpm@latest

# Install Moltbot from source
# Note: The npm package (moltbot@0.1.0) is incomplete and doesn't include the built binary.
# We need to build from source until a proper npm package is published.
# Docs recommend: npm install -g moltbot@latest (but current npm package is incomplete)
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/moltbot/moltbot.git && \
    cd moltbot && \
    pnpm install --frozen-lockfile && \
    pnpm build && \
    pnpm ui:build && \
    pnpm pack && \
    npm install -g ./moltbot-*.tgz && \
    cd / && \
    rm -rf /tmp/moltbot && \
    # Verify installation
    which moltbot || (echo "ERROR: moltbot not found after installation" && exit 1) && \
    moltbot --version || (echo "ERROR: moltbot command failed" && exit 1) && \
    # Clean up build dependencies and cache
    apt-get remove -y python3 make g++ && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* /root/.npm /root/.pnpm-store /var/lib/apt/lists/*

WORKDIR /

# Create directories
# /config is the single persistent volume mount point
# /tmp/moltbot is for transient logs (will use tmpfs)
RUN mkdir -p /config /tmp/moltbot && \
    chmod 1777 /tmp

# Copy entrypoint script
COPY start.sh /start.sh
RUN chmod +x /start.sh

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

# Health check using moltbot CLI
# The gateway health endpoint is available once running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf "http://127.0.0.1:${MOLTBOT_PORT:-18789}/health" || exit 1

# Use start.sh as entrypoint for PUID/PGID handling
ENTRYPOINT ["/start.sh"]

# Default command runs the gateway
# Can be overridden with: docker run ... moltbot-unraid <custom-command>
CMD ["gateway"]
