# Moltbot Unraid Docker Image
# Multi-platform base image (supports x86_64 and ARM64)
# Moltbot requires Node 24+ (package requirement: node >= 24)
# Using Debian-based image instead of Alpine for better native dependency support
FROM node:24-slim

# Set environment variables for Unraid compatibility
ENV PUID=1000
ENV PGID=1000
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
    git \
    curl \
    ca-certificates \
    passwd \
    && \
    rm -rf /var/lib/apt/lists/*

# Install moltbot from npm (pre-built package)
RUN npm install -g moltbot@latest && \
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

# Copy entrypoint and health check scripts
COPY start.sh /start.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /start.sh /healthcheck.sh

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

# Health check using dedicated script
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh

# Use start.sh as entrypoint for PUID/PGID handling
ENTRYPOINT ["/start.sh"]

# Default command runs the gateway
# Can be overridden with: docker run ... moltbot-unraid <custom-command>
CMD ["gateway"]
