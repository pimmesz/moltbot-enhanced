#!/bin/bash

# Moltbot Unraid Entrypoint (FIXED)
# Key fixes:
# - NO /root/.clawdbot or /root/clawd symlinks (prevents root-written state)
# - NO watchdog that fights symptoms
# - Only chown/chmod Moltbot-owned paths under /config
# - Always run gateway as PUID:PGID with HOME=/config so state is consistent

set -e

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

APP_PID=""

cleanup() {
  log "Received shutdown signal, cleaning up..."
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    log "Stopping Moltbot Gateway..."
    kill -TERM "$APP_PID" 2>/dev/null || true

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

if [ -z "${PUID:-}" ] || [ -z "${PGID:-}" ]; then
  log "==================================================================="
  log "❌ ERROR: PUID and PGID environment variables are required"
  log "==================================================================="
  log "For Unraid: PUID=99 and PGID=100"
  log "==================================================================="
  exit 1
fi

log "Starting Moltbot with PUID=$PUID, PGID=$PGID"

# ============================================================================
# AI Provider Validation (non-fatal)
# ============================================================================

if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${OPENAI_API_KEY:-}" ] && \
   [ -z "${OPENROUTER_API_KEY:-}" ] && [ -z "${GEMINI_API_KEY:-}" ]; then
  log "WARNING: No AI provider API key detected!"
  log "The gateway will start, but AI features will not work."
  log "Please set at least one of:"
  log "  - ANTHROPIC_API_KEY (recommended)"
  log "  - OPENAI_API_KEY"
  log "  - OPENROUTER_API_KEY"
  log "  - GEMINI_API_KEY"
  log ""
  log "Waiting 10 seconds before starting (Ctrl+C to cancel)..."
  sleep 10
fi

# ============================================================================
# User/Group Setup (Debian)
# ============================================================================

# Ensure group exists for PGID
if ! getent group "$PGID" >/dev/null 2>&1; then
  log "Creating group with GID $PGID"
  groupadd -g "$PGID" moltbot 2>/dev/null || true
fi

GROUP_NAME="$(getent group "$PGID" | cut -d: -f1 || echo "moltbot")"

# Ensure user exists for PUID
if ! getent passwd "$PUID" >/dev/null 2>&1; then
  log "Creating user with UID $PUID"
  # Home is /config, no home dir creation (-M) because /config is a volume
  useradd -u "$PUID" -g "$GROUP_NAME" -d /config -s /bin/bash -M moltbot 2>/dev/null || true
fi

# ============================================================================
# Timezone Configuration
# ============================================================================

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
  log "Setting timezone to $TZ"
  ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
fi

# ============================================================================
# State Directory Setup
# ============================================================================

# Moltbot CLI uses ~/.clawdbot internally.
# We force HOME=/config for the gateway (and wrapper should do the same for CLI).
MOLTBOT_STATE="/config/.clawdbot"
MOLTBOT_WORKSPACE="/config/workspace"
TOKEN_FILE="$MOLTBOT_STATE/.moltbot_token"

log "Initializing state directories..."
log "State directory: $MOLTBOT_STATE"
log "Workspace: $MOLTBOT_WORKSPACE"

mkdir -p "$MOLTBOT_STATE" "$MOLTBOT_WORKSPACE" /tmp/moltbot
mkdir -p "$MOLTBOT_STATE/agents/main/sessions" "$MOLTBOT_STATE/agents/main/state"

# Optional: keep /config/clawd for convenience
if [ ! -L /config/clawd ]; then
  ln -sf "$MOLTBOT_WORKSPACE" /config/clawd 2>/dev/null || true
fi

# Migrate old /config/.moltbot -> /config/.clawdbot
OLD_STATE="/config/.moltbot"
if [ -d "$OLD_STATE" ] && [ ! -L "$OLD_STATE" ] && [ "$OLD_STATE" != "$MOLTBOT_STATE" ]; then
  log "Migrating config from $OLD_STATE to $MOLTBOT_STATE..."
  cp -rn "$OLD_STATE"/* "$MOLTBOT_STATE/" 2>/dev/null || true
  mv "$OLD_STATE" "$OLD_STATE.migrated.$(date +%s)"
  log "Old config backed up to $OLD_STATE.migrated.*"
fi

# ============================================================================
# Token Handling (BEFORE config creation)
# ============================================================================

if [ -n "${MOLTBOT_TOKEN:-}" ]; then
  FINAL_TOKEN="$MOLTBOT_TOKEN"
  log "Using token from MOLTBOT_TOKEN environment variable"
elif [ -f "$TOKEN_FILE" ]; then
  FINAL_TOKEN="$(cat "$TOKEN_FILE")"
  log "Using auto-generated token from previous run"
else
  FINAL_TOKEN="$(openssl rand -hex 32)"
  echo "$FINAL_TOKEN" > "$TOKEN_FILE"
  log "==================================================================="
  log "AUTO-GENERATED GATEWAY TOKEN (save this for API access):"
  log "$FINAL_TOKEN"
  log "==================================================================="
  log "Token saved to: $TOKEN_FILE"
fi

export MOLTBOT_TOKEN="$FINAL_TOKEN"

# ============================================================================
# Ownership + Permissions (ONLY moltbot-owned paths)
# ============================================================================

# Ensure ownership before writing/patching config
chown -R "$PUID:$PGID" "$MOLTBOT_STATE" "$MOLTBOT_WORKSPACE" /tmp/moltbot 2>/dev/null || true

# State should be private
chmod 700 "$MOLTBOT_STATE" 2>/dev/null || true
find "$MOLTBOT_STATE" -type d -exec chmod 700 {} \; 2>/dev/null || true

# Workspace can be readable (adjust if you want stricter)
chmod 755 "$MOLTBOT_WORKSPACE" 2>/dev/null || true
find "$MOLTBOT_WORKSPACE" -type d -exec chmod 755 {} \; 2>/dev/null || true

# Token file must be private
if [ -f "$TOKEN_FILE" ]; then
  chown "$PUID:$PGID" "$TOKEN_FILE" 2>/dev/null || true
  chmod 600 "$TOKEN_FILE" 2>/dev/null || true
fi

# ============================================================================
# Config File Setup
# ============================================================================

CONFIG_PATH="$MOLTBOT_STATE/moltbot.json"

write_default_config() {
  cat > "$CONFIG_PATH" <<EOF
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
  chown "$PUID:$PGID" "$CONFIG_PATH" 2>/dev/null || true
  chmod 600 "$CONFIG_PATH" 2>/dev/null || true
}

if [ ! -f "$CONFIG_PATH" ]; then
  log "Creating default Moltbot configuration..."
  write_default_config
else
  # Validate JSON; if invalid, back up and recreate
  if ! python3 -c "import json; json.load(open('$CONFIG_PATH'))" 2>/dev/null; then
    log "WARNING: moltbot.json appears to be invalid JSON"
    log "Backing up and recreating default configuration..."
    mv "$CONFIG_PATH" "$CONFIG_PATH.backup.$(date +%s)"
    write_default_config
    log "Old config backed up with .backup suffix"
  else
    # Patch in required bits without rewriting ownership as root
    log "Ensuring config has required settings..."
    python3 <<PYTHON
import json, sys

p = "$CONFIG_PATH"
token = "$FINAL_TOKEN"
port = ${MOLTBOT_PORT:-18789}
bind = "${MOLTBOT_BIND:-lan}"

try:
    with open(p, "r") as f:
        cfg = json.load(f)

    modified = False

    cfg.setdefault("gateway", {})
    cfg["gateway"].setdefault("auth", {})
    cfg["gateway"].setdefault("controlUi", {})
    cfg.setdefault("agents", {}).setdefault("defaults", {})

    # Keep port/bind aligned with env
    if cfg["gateway"].get("port") != port:
        cfg["gateway"]["port"] = port
        modified = True
    if cfg["gateway"].get("bind") != bind:
        cfg["gateway"]["bind"] = bind
        modified = True

    # Auth token
    if cfg["gateway"]["auth"].get("token") != token or cfg["gateway"]["auth"].get("mode") != "token":
        cfg["gateway"]["auth"]["mode"] = "token"
        cfg["gateway"]["auth"]["token"] = token
        modified = True

    # Workspace default
    if cfg["agents"]["defaults"].get("workspace") != "/config/workspace":
        cfg["agents"]["defaults"]["workspace"] = "/config/workspace"
        modified = True

    # allowInsecureAuth
    if cfg["gateway"]["controlUi"].get("allowInsecureAuth") is not True:
        cfg["gateway"]["controlUi"]["allowInsecureAuth"] = True
        modified = True

    if modified:
        with open(p, "w") as f:
            json.dump(cfg, f, indent=2)
            f.write("\\n")
        print("✅ Config updated")
    else:
        print("✅ Config already up to date")

except Exception as e:
    print(f"⚠️  Could not update config: {e}", file=sys.stderr)
    sys.exit(0)
PYTHON

    # After Python writes (as root), fix ownership + perms back
    chown "$PUID:$PGID" "$CONFIG_PATH" 2>/dev/null || true
    chmod 600 "$CONFIG_PATH" 2>/dev/null || true
  fi
fi

# Verify non-root can read config
if ! gosu "$PUID:$PGID" test -r "$CONFIG_PATH" 2>/dev/null; then
  log "❌ ERROR: Config exists but is not readable by UID $PUID"
  log "Fixing ownership/perms..."
  chown "$PUID:$PGID" "$CONFIG_PATH" 2>/dev/null || true
  chmod 600 "$CONFIG_PATH" 2>/dev/null || true
fi

# ============================================================================
# Environment Setup for Non-Root User
# ============================================================================

export HOME=/config
export MOLTBOT_STATE_DIR="$MOLTBOT_STATE"
export XDG_CONFIG_HOME=/config
export XDG_DATA_HOME=/config
export XDG_CACHE_HOME=/config/.cache
export XDG_RUNTIME_DIR=/tmp/moltbot

export npm_config_cache=/config/.npm
export npm_config_prefix=/config/.npm-global
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# ============================================================================
# Command Construction
# ============================================================================

if ! command -v moltbot >/dev/null 2>&1; then
  log "==================================================================="
  log "❌ ERROR: moltbot binary not found"
  log "==================================================================="
  exit 1
fi

MOLTBOT_BIN="moltbot"
log "moltbot binary located at: $(which moltbot)"

if [ $# -eq 0 ] || [ "${1:-}" = "gateway" ]; then
  CMD="$MOLTBOT_BIN gateway"

  if [ -n "${MOLTBOT_PORT:-}" ]; then
    CMD="$CMD --port $MOLTBOT_PORT"
  fi

  if [ -n "${MOLTBOT_BIND:-}" ]; then
    CMD="$CMD --bind $MOLTBOT_BIND"
  fi

  if [ "${1:-}" = "gateway" ]; then
    shift
  fi

  if [ $# -gt 0 ]; then
    CMD="$CMD $*"
  fi
elif [ "${1:-}" = "shell" ]; then
  log "Starting interactive shell..."
  exec gosu "$PUID:$PGID" env HOME=/config /bin/bash
else
  CMD="$MOLTBOT_BIN $*"
fi

if [ -n "${MOLTBOT_CMD:-}" ]; then
  log "Using command override from MOLTBOT_CMD environment variable"
  CMD="$MOLTBOT_CMD"
fi

# ============================================================================
# Launch Application
# ============================================================================

log "Executing: $CMD"

# IMPORTANT: set HOME=/config for the child process explicitly
gosu "$PUID:$PGID" env HOME=/config sh -c "$CMD" &
APP_PID=$!

# Wait a moment, then show welcome message
sleep 3
if kill -0 "$APP_PID" 2>/dev/null; then
  BIND_ADDR="${MOLTBOT_BIND:-