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

# ============================================================================
# Token Handling - BEFORE config creation
# ============================================================================
# We need the token first so we can put it in the config file
TOKEN_FILE="$MOLTBOT_STATE/.moltbot_token"
if [ -n "$MOLTBOT_TOKEN" ]; then
    # User provided token via environment
    FINAL_TOKEN="$MOLTBOT_TOKEN"
    log "Using token from MOLTBOT_TOKEN environment variable"
elif [ -f "$TOKEN_FILE" ]; then
    # Use previously generated token
    FINAL_TOKEN=$(cat "$TOKEN_FILE")
    log "Using auto-generated token from previous run"
else
    # Generate new token on first run
    FINAL_TOKEN=$(openssl rand -hex 32)
    echo "$FINAL_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    chown "$PUID:$PGID" "$TOKEN_FILE"
    log "==================================================================="
    log "AUTO-GENERATED GATEWAY TOKEN (save this for API access):"
    log "$FINAL_TOKEN"
    log "==================================================================="
    log "Token saved to: $TOKEN_FILE"
fi

# Export for child processes
export MOLTBOT_TOKEN="$FINAL_TOKEN"

# ============================================================================
# Config File Setup
# ============================================================================
# Initialize default config if not exists - WITH TOKEN INCLUDED
if [ ! -f "$MOLTBOT_STATE/moltbot.json" ]; then
    log "Creating default Moltbot configuration..."
    cat > "$MOLTBOT_STATE/moltbot.json" <<EOF
{
  "gateway": {
    "mode": "local",
    "port": ${MOLTBOT_PORT:-18789},
    "bind": "${MOLTBOT_BIND:-lan}",
    "auth": {
      "mode": "token",
      "token": "$FINAL_TOKEN"
    },
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
    "auth": {
      "mode": "token",
      "token": "$FINAL_TOKEN"
    },
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
        # Patch existing config to ensure all required settings are present
        log "Ensuring config has required settings..."
        python3 <<PYTHON
import json
import sys

try:
    with open('$MOLTBOT_STATE/moltbot.json', 'r') as f:
        config = json.load(f)
    
    modified = False
    
    # Ensure gateway structure exists
    if 'gateway' not in config:
        config['gateway'] = {}
        modified = True
    
    # Ensure auth structure exists with token
    if 'auth' not in config['gateway']:
        config['gateway']['auth'] = {}
        modified = True
    
    # Set auth mode and token
    if config['gateway']['auth'].get('token') != '$FINAL_TOKEN':
        config['gateway']['auth']['mode'] = 'token'
        config['gateway']['auth']['token'] = '$FINAL_TOKEN'
        modified = True
        print("✅ Updated auth token in config")
    
    # Ensure controlUi structure exists
    if 'controlUi' not in config['gateway']:
        config['gateway']['controlUi'] = {}
        modified = True
    
    # Set allowInsecureAuth
    if not config['gateway']['controlUi'].get('allowInsecureAuth'):
        config['gateway']['controlUi']['allowInsecureAuth'] = True
        modified = True
        print("✅ Enabled insecure HTTP access in config")
    
    if modified:
        with open('$MOLTBOT_STATE/moltbot.json', 'w') as f:
            json.dump(config, f, indent=2)
    else:
        print("✅ Config already up to date")
        
except Exception as e:
    print(f"⚠️  Could not update config: {e}", file=sys.stderr)
    sys.exit(0)  # Don't fail startup if patch fails
PYTHON
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
    
    # Token is already set in config file and exported as MOLTBOT_TOKEN
    # moltbot reads token from config, no need for --token flag
    
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
    # Get actual bind address for UI URL
    BIND_ADDR="${MOLTBOT_BIND:-lan}"
    if [ "$BIND_ADDR" = "loopback" ]; then
        UI_HOST="localhost"
    else
        # Try to detect the actual IP address
        UI_HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [ -z "$UI_HOST" ]; then
            UI_HOST="localhost"
        fi
    fi
    UI_PORT="${MOLTBOT_PORT:-18789}"
    
    log "==================================================================="
    log "✅ Moltbot Gateway Started"
    log "==================================================================="
    log ""
    log "Web UI (copy and paste this URL):"
    log "  http://${UI_HOST}:${UI_PORT}/?token=${FINAL_TOKEN}"
    log ""
    log "Gateway Token: ${FINAL_TOKEN}"
    log ""
    log "CLI Commands:"
    log "  Setup:  docker exec -it moltbot moltbot onboard"
    log "  Health: docker exec moltbot moltbot doctor"
    log "  Status: docker exec moltbot moltbot status"
    log ""
    log "Config: /config/.moltbot/"
    log "==================================================================="
fi

# Wait for the application and forward signals
wait $APP_PID
EXIT_CODE=$?

log "Application exited with code $EXIT_CODE"
exit $EXIT_CODE
