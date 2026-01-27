# Multi-platform base image (supports x86_64 and ARM64)
# Moltbot requires Node 22+
FROM node:22-alpine

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
# - shadow: usermod/groupmod for PUID/PGID
# - tzdata: timezone support
# - su-exec: lightweight privilege dropping
# - bash: shell compatibility
# - git: some moltbot features may need git
# - curl: health checks and downloads
RUN apk add --no-cache \
    shadow \
    tzdata \
    su-exec \
    bash \
    git \
    curl && \
    rm -rf /var/cache/apk/*

# Install Moltbot globally
# Pin version if specified, otherwise use latest
RUN npm install -g "moltbot@${MOLTBOT_VERSION}" --no-audit --no-fund && \
    npm cache clean --force && \
    rm -rf /tmp/* /root/.npm

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
LABEL org.opencontainers.image.url="https://github.com/pimmesz/clawdbot-unraid"
LABEL org.opencontainers.image.source="https://github.com/pimmesz/clawdbot-unraid"
LABEL org.opencontainers.image.documentation="https://github.com/pimmesz/clawdbot-unraid/blob/main/README.md"

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
