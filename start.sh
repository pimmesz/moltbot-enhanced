#!/bin/bash
set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Unraid compatibility - set user/group
PUID=${PUID:-99}
PGID=${PGID:-100}

log_info "Starting Moltbot container..."
log_info "  PUID: $PUID"
log_info "  PGID: $PGID"
log_info "  TZ: ${TZ:-UTC}"

# Create moltbot group if it doesn't exist
if ! getent group moltbot > /dev/null 2>&1; then
    groupadd -g "$PGID" moltbot 2>/dev/null || groupmod -g "$PGID" moltbot 2>/dev/null || true
    log_info "Created group 'moltbot' with GID $PGID"
fi

# Create moltbot user if it doesn't exist
if ! id -u moltbot > /dev/null 2>&1; then
    useradd -u "$PUID" -g "$PGID" -d /config -s /bin/bash moltbot 2>/dev/null || \
    usermod -u "$PUID" -g "$PGID" moltbot 2>/dev/null || true
    log_info "Created user 'moltbot' with UID $PUID"
fi

# Create required directories
mkdir -p /config /config/moltbot /tmp/moltbot /var/log/moltbot

# Set ownership
chown -R "$PUID:$PGID" /config /tmp/moltbot /var/log/moltbot 2>/dev/null || true

# Set timezone if provided
if [ -n "$TZ" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    log_info "Timezone set to $TZ"
fi

# Start Xvfb for headless browser support (if installed and DISPLAY not set)
if [ -z "$DISPLAY" ] && command -v Xvfb > /dev/null 2>&1; then
    export DISPLAY=:99
    Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset > /dev/null 2>&1 &
    XVFB_PID=$!
    log_info "Started Xvfb on display :99 (PID: $XVFB_PID)"
    sleep 2
fi

# Export environment for moltbot
export HOME=/config
export MOLTBOT_CONFIG_DIR="${MOLTBOT_CONFIG_DIR:-/config/moltbot}"
export MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
export MOLTBOT_BIND="${MOLTBOT_BIND:-lan}"

log_info "Starting moltbot gateway..."
log_info "  Config: $MOLTBOT_CONFIG_DIR"
log_info "  Port: $MOLTBOT_PORT"
log_info "  Bind: $MOLTBOT_BIND"

# Run moltbot as the specified user
exec gosu "$PUID:$PGID" moltbot-real "$@"
