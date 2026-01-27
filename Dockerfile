# Multi-stage build for better caching and faster builds
# Stage 1: Build moltbot
FROM node:24-slim AS builder

WORKDIR /build

# Install build dependencies only
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

# Clone moltbot repository
# Note: The npm package is incomplete, so we build from source.
# TODO: Once a pre-built npm package is available, simplify to: npm install -g moltbot@latest
RUN git clone --depth 1 https://github.com/moltbot/moltbot.git .

# Install dependencies (this layer will be cached if package.json doesn't change)
# Use BuildKit cache mount for faster subsequent builds
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# Build and package
RUN pnpm build && \
    pnpm ui:build && \
    pnpm pack

# Stage 2: Final image
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

# Install runtime dependencies only (no build tools needed)
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
