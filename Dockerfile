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
ENV PUID=99
ENV PGID=100
ENV TZ=UTC

# Gateway configuration defaults
ENV MOLTBOT_PORT=18789
ENV MOLTBOT_BIND=lan

# Install essential runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gosu \
    tzdata \
    git \
    curl \
    ca-certificates \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    && \
    rm -rf /var/lib/apt/lists/*

# Install audio/video and additional tools in separate layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ffmpeg \
    sox \
    sqlite3 \
    postgresql-client \
    jq \
    wget \
    unzip \
    && \
    rm -rf /var/lib/apt/lists/*

# === Install Balanced Python Packages ===
RUN pip3 install --no-cache-dir \
    # Web & automation
    requests \
    beautifulsoup4 \
    selenium \
    playwright \
    \
    # Data processing
    pandas \
    numpy \
    \
    # Utilities
    pillow \
    pyyaml \
    python-dotenv \
    \
    # Database
    sqlalchemy \
    psycopg2-binary \
    redis \
    \
    # IoT
    paho-mqtt \
    zeroconf \
    \
    # Time
    pytz \
    python-dateutil \
    \
    # Security
    cryptography

# === Install Playwright browsers for fallback automation ===
RUN python3 -m playwright install chromium --with-deps

# === Install Node.js utilities ===

RUN npm install -g \
    pm2 \
    http-server

# Copy and install the built package from builder stage
COPY --from=builder /build/moltbot-*.tgz /tmp/moltbot.tgz

RUN npm install -g /tmp/moltbot.tgz && \
    rm -f /tmp/moltbot.tgz && \
    npm cache clean --force && \
    rm -rf /root/.npm && \
    which moltbot || (echo "ERROR: moltbot binary not found" && exit 1) && \
    moltbot --version || (echo "ERROR: moltbot command failed" && exit 1)

WORKDIR /

# Create directories
RUN mkdir -p /config /tmp/moltbot && \
    chmod 1777 /tmp

# Copy entrypoint, health check, and wrapper scripts
COPY start.sh /start.sh
COPY healthcheck.sh /healthcheck.sh
COPY moltbot-wrapper.sh /usr/local/bin/moltbot-wrapper
RUN chmod +x /start.sh /healthcheck.sh /usr/local/bin/moltbot-wrapper

# Replace moltbot binary with wrapper
RUN mv /usr/local/bin/moltbot /usr/local/bin/moltbot-real && \
    ln -sf /usr/local/bin/moltbot-wrapper /usr/local/bin/moltbot

# Metadata labels
LABEL maintainer="pimmesz"
LABEL org.opencontainers.image.title="Moltbot Unraid - AI Butler"
LABEL org.opencontainers.image.description="Smart home butler with browser automation, audio processing, and data analytics"
LABEL org.opencontainers.image.authors="pimmesz"
LABEL org.opencontainers.image.url="https://github.com/pimmesz/moltbot-unraid"
LABEL org.opencontainers.image.source="https://github.com/pimmesz/moltbot-unraid"
LABEL org.opencontainers.image.documentation="https://github.com/pimmesz/moltbot-unraid/blob/main/README.md"

EXPOSE 18789
VOLUME ["/config"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh

ENTRYPOINT ["/start.sh"]
CMD ["gateway"]
