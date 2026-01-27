#!/bin/sh

# Moltbot Unraid Entrypoint
# Handles PUID/PGID, state initialization, and privilege dropping
# Based on binhex/arch-radarr pattern for Unraid compatibility

set -e

# ============================================================================
# Logging
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# ============================================================================
# Signal Handling
# ============================================================================

APP_PID=""

cleanup() {
    log "Received shutdown signal, cleaning up..."
    if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
        kill -TERM "$APP_PID" 2>/dev/null || true
        # Wait with timeout
        timeout=30
        while [ $timeout -gt 0 ] && kill -0 "$APP_PID" 2>/dev/null; do
            sleep 1
            timeout=$((timeout - 1))
        done
        if kill -0 "$APP_PID" 2>/dev/null; then
            log "Process did not terminate gracefully, sending SIGKILL"
            kill -KILL "$APP_PID" 2>/dev/null || true
        fi
    fi
    log "Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT

# ============================================================================
# Validate Environment
# ============================================================================

if [ -z "$PUID" ] || [ -z "$PGID" ]; then
    log "ERROR: PUID and PGID must be set"
    exit 1
fi

log "Starting Moltbot with PUID=$PUID, PGID=$PGID"

# ============================================================================
# User/Group Setup (Alpine Linux)
# ============================================================================

# Create group if it doesn't exist
if ! getent group "$PGID" >/dev/null 2>&1; then
    log "Creating group with GID $PGID"
    addgroup -g "$PGID" moltbot 2>/dev/null || true
fi

# Get group name for the GID
GROUP_NAME=$(getent group "$PGID" | cut -d: -f1 || echo "moltbot")

# Create user if it doesn't exist
if ! getent passwd "$PUID" >/dev/null 2>&1; then
    log "Creating user with UID $PUID"
    adduser -u "$PUID" -G "$GROUP_NAME" -D -h /config -s /bin/sh moltbot 2>/dev/null || true
fi

# Get username for the UID
USER_NAME=$(getent passwd "$PUID" | cut -d: -f1 || echo "moltbot")

# ============================================================================
# Timezone Configuration
# ============================================================================

if [ -n "$TZ" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
    log "Setting timezone to $TZ"
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
fi

# ============================================================================
# State Directory Setup
# ============================================================================

# Moltbot state directories
# We set HOME=/config so ~/.moltbot becomes /config/.moltbot
MOLTBOT_STATE="/config/.moltbot"
MOLTBOT_WORKSPACE="/config/workspace"

log "Initializing state directories..."

# Create required directories
mkdir -p "$MOLTBOT_STATE" "$MOLTBOT_WORKSPACE" /tmp/moltbot

# Initialize default config if not exists
if [ ! -f "$MOLTBOT_STATE/moltbot.json" ]; then
    log "Creating default Moltbot configuration..."
    cat > "$MOLTBOT_STATE/moltbot.json" <<EOF
{
  "gateway": {
    "port": ${MOLTBOT_PORT:-18789},
    "bind": "${MOLTBOT_BIND:-lan}"
  },
  "agents": {
    "defaults": {
      "workspace": "/config/workspace"
    }
  }
}
EOF
fi

# Set ownership
log "Setting ownership of /config to $PUID:$PGID"
chown -R "$PUID:$PGID" /config
chown -R "$PUID:$PGID" /tmp/moltbot 2>/dev/null || true

# ============================================================================
# Environment Setup for Non-Root User
# ============================================================================

# These env vars ensure all state goes to /config
export HOME=/config
export MOLTBOT_STATE_DIR="$MOLTBOT_STATE"
export XDG_CONFIG_HOME=/config
export XDG_DATA_HOME=/config
export XDG_CACHE_HOME=/config/.cache
export XDG_RUNTIME_DIR=/tmp/moltbot

# Ensure npm doesn't write to /root
export npm_config_cache=/config/.npm
export npm_config_prefix=/config/.npm-global

# ============================================================================
# Command Construction
# ============================================================================

# Default command if none provided
if [ $# -eq 0 ] || [ "$1" = "gateway" ]; then
    # Build gateway command with env-based options
    CMD="moltbot gateway"
    
    # Add port if specified
    if [ -n "$MOLTBOT_PORT" ]; then
        CMD="$CMD --port $MOLTBOT_PORT"
    fi
    
    # Add bind mode if specified
    if [ -n "$MOLTBOT_BIND" ]; then
        CMD="$CMD --bind $MOLTBOT_BIND"
    fi
    
    # Add token if specified (for auth)
    if [ -n "$MOLTBOT_TOKEN" ]; then
        CMD="$CMD --token $MOLTBOT_TOKEN"
    fi
    
    # Skip the "gateway" arg if it was passed
    if [ "$1" = "gateway" ]; then
        shift
    fi
    
    # Append any extra args
    if [ $# -gt 0 ]; then
        CMD="$CMD $*"
    fi
elif [ "$1" = "shell" ]; then
    # Debug mode: drop into shell
    log "Starting interactive shell..."
    exec su-exec "$PUID:$PGID" /bin/sh
else
    # Custom command (e.g., moltbot health, moltbot status)
    CMD="moltbot $*"
fi

# Allow complete command override
if [ -n "$MOLTBOT_CMD" ]; then
    CMD="$MOLTBOT_CMD"
fi

# ============================================================================
# Launch Application
# ============================================================================

log "Executing: $CMD"

# Use exec form for proper signal handling
# su-exec replaces the shell with the target process
exec su-exec "$PUID:$PGID" sh -c "$CMD" &
APP_PID=$!

# Wait for the application
wait $APP_PID
EXIT_CODE=$?

log "Application exited with code $EXIT_CODE"
exit $EXIT_CODE
