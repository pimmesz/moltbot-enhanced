#!/bin/bash
# Moltbot Unraid Entrypoint (FINAL, FIXED)
#
# Rules:
# - /config/.clawdbot is the single source of truth
# - moltbot.json is CREATED once, never patched
# - Moltbot owns its config after first boot
# - No CLI flags that override config
# - PUID/PGID handled here, nowhere else

set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2; }

APP_PID=""

cleanup() {
  log "Received shutdown signal"
  if [ -n "${APP_PID:-}" ] && kill -0 "$APP_PID" 2>/dev/null; then
    log "Stopping Moltbot Gateway..."
    kill -TERM "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  log "Shutdown complete"
  exit 0
}
trap cleanup TERM INT

# ============================================================================
# Validate environment
# ============================================================================

PUID="${PUID:-}"
PGID="${PGID:-}"

if [ -z "$PUID" ] || [ -z "$PGID" ]; then
  log "❌ ERROR: PUID and PGID must be set (Unraid default: 99:100)"
  exit 1
fi

log "Starting Moltbot with PUID=$PUID PGID=$PGID"

# ============================================================================
# User / group setup
# ============================================================================

if ! getent group "$PGID" >/dev/null 2>&1; then
  groupadd -g "$PGID" moltbot 2>/dev/null || true
fi

GROUP_NAME="$(getent group "$PGID" | cut -d: -f1)"

if ! getent passwd "$PUID" >/dev/null 2>&1; then
  useradd -u "$PUID" -g "$GROUP_NAME" -d /config -s /bin/bash -M moltbot 2>/dev/null || true
fi

# ============================================================================
# Timezone
# ============================================================================

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
  log "Setting timezone to $TZ"
  ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
fi

# ============================================================================
# Paths
# ============================================================================

export HOME=/config
export XDG_CONFIG_HOME=/config
export XDG_DATA_HOME=/config
export XDG_CACHE_HOME=/config/.cache
export XDG_RUNTIME_DIR=/tmp/moltbot

MOLTBOT_STATE="/config/.clawdbot"
MOLTBOT_WORKSPACE="/config/workspace"
CONFIG_PATH="$MOLTBOT_STATE/moltbot.json"
TOKEN_FILE="$MOLTBOT_STATE/.moltbot_token"

export MOLTBOT_STATE_DIR="$MOLTBOT_STATE"
export MOLTBOT_CONFIG_PATH="$CONFIG_PATH"

log "State dir: $MOLTBOT_STATE"
log "Workspace: $MOLTBOT_WORKSPACE"

mkdir -p \
  "$MOLTBOT_STATE" \
  "$MOLTBOT_WORKSPACE" \
  "$XDG_CACHE_HOME" \
  "$XDG_RUNTIME_DIR"

# ============================================================================
# Permissions
# ============================================================================

chown -R "$PUID:$PGID" /config /tmp/moltbot 2>/dev/null || true
chmod 700 "$MOLTBOT_STATE" || true

# ============================================================================
# Gateway token (persistent)
# ============================================================================

if [ -n "${MOLTBOT_TOKEN:-}" ]; then
  FINAL_TOKEN="$MOLTBOT_TOKEN"
  log "Using MOLTBOT_TOKEN from environment"
elif [ -f "$TOKEN_FILE" ]; then
  FINAL_TOKEN="$(cat "$TOKEN_FILE")"
else
  FINAL_TOKEN="$(openssl rand -hex 32)"
  echo "$FINAL_TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  log "Generated new gateway token"
fi

export MOLTBOT_TOKEN="$FINAL_TOKEN"

# ============================================================================
# Config creation (ONCE)
# ============================================================================

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
  chown "$PUID:$PGID" "$CONFIG_PATH"
  chmod 600 "$CONFIG_PATH"
}

if [ ! -f "$CONFIG_PATH" ]; then
  log "Creating initial moltbot.json"
  write_default_config
else
  # Validate JSON only; never rewrite
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 -c "import json; json.load(open('$CONFIG_PATH'))" 2>/dev/null; then
      bad="$CONFIG_PATH.bad.$(date +%s)"
      log "Invalid config detected, backing up to $bad"
      mv "$CONFIG_PATH" "$bad"
      write_default_config
    else
      log "Existing moltbot.json detected – leaving untouched"
    fi
  fi
fi

# ============================================================================
# Launch Moltbot
# ============================================================================

if [ ! -x /usr/local/bin/moltbot-real ]; then
  log "❌ ERROR: moltbot-real not found"
  exit 1
fi

CMD="/usr/local/bin/moltbot-real gateway"
log "Executing: $CMD"

gosu "$PUID:$PGID" env HOME=/config sh -c "$CMD" &
APP_PID=$!

sleep 3
if kill -0 "$APP_PID" 2>/dev/null; then
  log "✅ Moltbot Gateway started"
  log "UI: http://localhost:${MOLTBOT_PORT:-18789}/?token=$FINAL_TOKEN"
fi

wait "$APP_PID"
exit_code=$?
log "Moltbot exited with code $exit_code"
exit "$exit_code"