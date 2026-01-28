#!/bin/bash

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
        log "Stopping Moltbot Gateway..."
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

trap cleanup TERM INT

# ============================================================================
# Validate Environment
# ============================================================================

if [ -z "$PUID" ] || [ -z "$PGID" ]; then
    log "==================================================================="
    log "❌ ERROR: PUID and PGID environment variables are required"
    log "==================================================================="
    log ""
    log "These variables control file permissions in the container."
    log ""
    log "For Unraid: Use PUID=99 and PGID=100 (default)"
    log "For local: Use your user ID and group ID"
    log ""
    log "To find your IDs, run:"
    log "  id -u  # Your PUID"
    log "  id -g  # Your PGID"
    log ""
    log "Then set in docker-compose.yml or .env file:"
    log "  PUID=1000"
    log "  PGID=1000"
    log "==================================================================="
    exit 1
fi

log "Starting Moltbot with PUID=$PUID, PGID=$PGID"

# ============================================================================
# AI Provider Validation
# ============================================================================

# Check if at least one AI provider API key is configured
if [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$OPENAI_API_KEY" ] && \
   [ -z "$OPENROUTER_API_KEY" ] && [ -z "$GEMINI_API_KEY" ]; then
    log "WARNING: No AI provider API key detected!"
    log "The gateway will start, but AI features will not work."
    log "Please set at least one of these environment variables:"
    log "  - ANTHROPIC_API_KEY (recommended)"
    log "  - OPENAI_API_KEY"
    log "  - OPENROUTER_API_KEY"
    log "  - GEMINI_API_KEY"
    log ""
    log "Waiting 10 seconds before starting (Ctrl+C to cancel)..."
    sleep 10
fi

# ============================================================================
# User/Group Setup (Debian Linux)
# ============================================================================

# Create group if it doesn't exist
if ! getent group "$PGID" >/dev/null 2>&1; then
    log "Creating group with GID $PGID"
    groupadd -g "$PGID" moltbot 2>/dev/null || true
fi

# Get group name for the GID
GROUP_NAME=$(getent group "$PGID" | cut -d: -f1 || echo "moltbot")

# Create user if it doesn't exist
if ! getent passwd "$PUID" >/dev/null 2>&1; then
    log "Creating user with UID $PUID"
    useradd -u "$PUID" -g "$GROUP_NAME" -d /config -s /bin/bash -M moltbot 2>/dev/null || true
fi

# Note: Username is available but not currently used
# USER_NAME=$(getent passwd "$PUID" | cut -d: -f1 || echo "moltbot")

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
    "mode": "local",
    "port": ${MOLTBOT_PORT:-18789},
    "bind": "${MOLTBOT_BIND:-lan}",
    "controlUi": {
      "allowInsecureAuth": true
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/config/workspace"
    }
  }
}
EOF
else
    # Validate existing config is valid JSON
    if ! python3 -c "import json; json.load(open('$MOLTBOT_STATE/moltbot.json'))" 2>/dev/null; then
        log "WARNING: moltbot.json appears to be invalid JSON"
        log "Backing up and recreating default configuration..."
        mv "$MOLTBOT_STATE/moltbot.json" "$MOLTBOT_STATE/moltbot.json.backup.$(date +%s)"
        cat > "$MOLTBOT_STATE/moltbot.json" <<EOF
{
  "gateway": {
    "mode": "local",
    "port": ${MOLTBOT_PORT:-18789},
    "bind": "${MOLTBOT_BIND:-lan}",
    "controlUi": {
      "allowInsecureAuth": true
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/config/workspace"
    }
  }
}
EOF
        log "Old config backed up with .backup suffix"
    else
        # Patch existing config to allow insecure HTTP access (if not already set)
        # This fixes the "control ui requires HTTPS or localhost" error
        if ! python3 -c "import json; c=json.load(open('$MOLTBOT_STATE/moltbot.json')); exit(0 if c.get('gateway', {}).get('controlUi', {}).get('allowInsecureAuth') else 1)" 2>/dev/null; then
            log "Adding allowInsecureAuth to gateway.controlUi for HTTP access..."
            python3 <<PYTHON
import json
import sys

try:
    with open('$MOLTBOT_STATE/moltbot.json', 'r') as f:
        config = json.load(f)
    
    # Ensure gateway.controlUi structure exists
    if 'gateway' not in config:
        config['gateway'] = {}
    if 'controlUi' not in config['gateway']:
        config['gateway']['controlUi'] = {}
    
    # Set allowInsecureAuth if not already set
    if not config['gateway']['controlUi'].get('allowInsecureAuth'):
        config['gateway']['controlUi']['allowInsecureAuth'] = True
        
        with open('$MOLTBOT_STATE/moltbot.json', 'w') as f:
            json.dump(config, f, indent=2)
        
        print("✅ Updated config to allow insecure HTTP access")
    else:
        print("✅ Config already has allowInsecureAuth set")
except Exception as e:
    print(f"⚠️  Could not update config: {e}", file=sys.stderr)
    sys.exit(0)  # Don't fail startup if patch fails
PYTHON
        fi
    fi
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

# Ensure PATH includes npm global bin directory
# npm global packages are installed to /usr/local/bin in Node.js images
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# ============================================================================
# Command Construction
# ============================================================================

# Verify moltbot is available
if ! command -v moltbot >/dev/null 2>&1; then
    log "==================================================================="
    log "❌ ERROR: moltbot binary not found"
    log "==================================================================="
    log ""
    log "This indicates the Docker image was not built correctly."
    log ""
    log "To fix this:"
    log "  1. Remove the container:"
    log "     docker-compose down"
    log ""
    log "  2. Rebuild from scratch:"
    log "     docker-compose build --no-cache"
    log ""
    log "  3. Start again:"
    log "     docker-compose up -d"
    log ""
    log "If the problem persists, check build logs for errors."
    log "==================================================================="
    exit 1
fi

MOLTBOT_BIN="moltbot"
log "moltbot binary located at: $(which moltbot)"

# Default command if none provided
if [ $# -eq 0 ] || [ "$1" = "gateway" ]; then
    # Build gateway command with env-based options
    CMD="$MOLTBOT_BIN gateway"
    
    # Add port if specified
    if [ -n "$MOLTBOT_PORT" ]; then
        CMD="$CMD --port $MOLTBOT_PORT"
    fi
    
    # Add bind mode if specified
    if [ -n "$MOLTBOT_BIND" ]; then
        CMD="$CMD --bind $MOLTBOT_BIND"
    fi
    
    # Handle token authentication
    TOKEN_FILE="$MOLTBOT_STATE/.moltbot_token"
    if [ -n "$MOLTBOT_TOKEN" ]; then
        # User provided token via environment
        export MOLTBOT_TOKEN
        CMD="$CMD --token $MOLTBOT_TOKEN"
    elif [ -f "$TOKEN_FILE" ]; then
        # Use previously generated token
        GENERATED_TOKEN=$(cat "$TOKEN_FILE")
        export MOLTBOT_TOKEN="$GENERATED_TOKEN"
        log "Using auto-generated token from previous run"
        CMD="$CMD --token $GENERATED_TOKEN"
    else
        # Generate new token on first run
        GENERATED_TOKEN=$(openssl rand -hex 32)
        echo "$GENERATED_TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        chown "$PUID:$PGID" "$TOKEN_FILE"
        export MOLTBOT_TOKEN="$GENERATED_TOKEN"
        log "==================================================================="
        log "AUTO-GENERATED GATEWAY TOKEN (save this for API access):"
        log "$GENERATED_TOKEN"
        log "==================================================================="
        log "Token saved to: $TOKEN_FILE"
        log "To use a custom token, set MOLTBOT_TOKEN environment variable"
        CMD="$CMD --token $GENERATED_TOKEN"
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
    exec gosu "$PUID:$PGID" /bin/bash
else
    # Custom command (e.g., moltbot health, moltbot status)
    CMD="$MOLTBOT_BIN $*"
fi

# Allow complete command override via MOLTBOT_CMD environment variable
# This overrides the entire command, not just the binary path
if [ -n "${MOLTBOT_CMD:-}" ]; then
    log "Using command override from MOLTBOT_CMD environment variable"
    CMD="$MOLTBOT_CMD"
fi

# ============================================================================
# Launch Application
# ============================================================================

log "Executing: $CMD"

# Use gosu to run as non-root user
# Note: We can't use exec here because we need to wait for the process
gosu "$PUID:$PGID" sh -c "$CMD" &
APP_PID=$!

# Wait a moment for startup, then show welcome message
sleep 3
if kill -0 "$APP_PID" 2>/dev/null; then
    log "==================================================================="
    log "✅ Moltbot Gateway Started"
    log "==================================================================="
    log ""
    log "Gateway: http://localhost:${MOLTBOT_PORT:-18789}"
    log ""
    log "Setup:"
    log "  docker exec -it moltbot moltbot onboard"
    log ""
    log "Health:"
    log "  docker exec moltbot moltbot doctor"
    log ""
    log "Status:"
    log "  docker exec moltbot moltbot status"
    log ""
    log "Config: /config/.moltbot/"
    log "==================================================================="
fi

# Wait for the application and forward signals
wait $APP_PID
EXIT_CODE=$?

log "Application exited with code $EXIT_CODE"
exit $EXIT_CODE
