#!/bin/bash
# Moltbot Unraid Entrypoint
#
# Goals:
# - /config/.clawdbot is the state directory (moltbot's default)
# - Never write state under /root
# - Create moltbot.json ONCE (if missing/invalid). Never patch it afterwards.
# - Run gateway as PUID:PGID with HOME=/config (so plugins/channels persist)
# - Keep permissions deterministic without chowning all of /config

set -euo pipefail

# Set permissive umask so moltbot can read/write all files it creates
umask 0002

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2; }

APP_PID=""
XVFB_PID=""

cleanup() {
  log "Received shutdown signal"
  if [ -n "${APP_PID:-}" ] && kill -0 "$APP_PID" 2>/dev/null; then
    log "Stopping Moltbot..."
    kill -TERM "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  if [ -n "${XVFB_PID:-}" ] && kill -0 "$XVFB_PID" 2>/dev/null; then
    log "Stopping Xvfb..."
    kill "$XVFB_PID" 2>/dev/null || true
  fi
  log "Shutdown complete"
  exit 0
}
trap cleanup TERM INT

# ---------------------------------------------------------------------------
# Validate env
# ---------------------------------------------------------------------------

PUID="${PUID:-}"
PGID="${PGID:-}"

if [ -z "$PUID" ] || [ -z "$PGID" ]; then
  log "❌ ERROR: PUID and PGID must be set (Unraid default: 99:100)"
  exit 1
fi

log "Starting Moltbot with PUID=$PUID PGID=$PGID"

# ---------------------------------------------------------------------------
# User/group
# ---------------------------------------------------------------------------

if ! getent group "$PGID" >/dev/null 2>&1; then
  groupadd -g "$PGID" moltbot 2>/dev/null || true
fi
GROUP_NAME="$(getent group "$PGID" | cut -d: -f1 || echo "moltbot")"

if ! getent passwd "$PUID" >/dev/null 2>&1; then
  useradd -u "$PUID" -g "$GROUP_NAME" -d /config -s /bin/bash -M moltbot 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# TZ
# ---------------------------------------------------------------------------

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
  log "Setting timezone to $TZ"
  ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
fi

# ---------------------------------------------------------------------------
# Pin paths
# ---------------------------------------------------------------------------

export HOME=/config
export XDG_CONFIG_HOME=/config
export XDG_DATA_HOME=/config
export XDG_CACHE_HOME=/config/.cache
export XDG_RUNTIME_DIR=/tmp/moltbot
export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

# Ensure browser automation uses the container-safe Chromium wrapper
export PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chromium-wrapper

# Use .clawdbot as state dir (moltbot's default, for backward compatibility)
MOLTBOT_STATE="/config/.clawdbot"
MOLTBOT_WORKSPACE="/config/workspace"
CONFIG_PATH="$MOLTBOT_STATE/moltbot.json"
TOKEN_FILE="$MOLTBOT_STATE/.moltbot_token"
CRED_DIR="$MOLTBOT_STATE/credentials"

export MOLTBOT_STATE_DIR="$MOLTBOT_STATE"

log "State dir: $MOLTBOT_STATE"
log "Workspace: $MOLTBOT_WORKSPACE"

mkdir -p \
  "$MOLTBOT_STATE" \
  "$MOLTBOT_WORKSPACE" \
  "$CRED_DIR" \
  "$XDG_CACHE_HOME" \
  "$XDG_RUNTIME_DIR"

# ---------------------------------------------------------------------------
# Permissions (DON’T chown all of /config)
# IMPORTANT: docker exec as root may create/modify files -> we correct on boot.
# ---------------------------------------------------------------------------

# Fix ownership recursively for all state directories
chown -R "$PUID:$PGID" \
  "$MOLTBOT_STATE" \
  "$MOLTBOT_WORKSPACE" \
  "$XDG_CACHE_HOME" \
  "$XDG_RUNTIME_DIR" \
  2>/dev/null || true

# Make all directories group-writable (775 = rwxrwxr-x)
find "$MOLTBOT_STATE" -type d -exec chmod 775 {} \; 2>/dev/null || true
chmod 775 "$MOLTBOT_WORKSPACE" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Make all files group-writable (664 = rw-rw-r--)
find "$MOLTBOT_STATE" -type f -exec chmod 664 {} \; 2>/dev/null || true

# Credentials dir stays more restrictive
chmod 770 "$CRED_DIR" 2>/dev/null || true

log "Fixed permissions on state directories"

# ---------------------------------------------------------------------------
# Token (persistent)
# ---------------------------------------------------------------------------

if [ -n "${MOLTBOT_TOKEN:-}" ]; then
  FINAL_TOKEN="$MOLTBOT_TOKEN"
  log "Using MOLTBOT_TOKEN from environment"
elif [ -f "$TOKEN_FILE" ]; then
  FINAL_TOKEN="$(cat "$TOKEN_FILE")"
else
  FINAL_TOKEN="$(openssl rand -hex 32)"
  echo "$FINAL_TOKEN" > "$TOKEN_FILE"
  chown "$PUID:$PGID" "$TOKEN_FILE" 2>/dev/null || true
  chmod 660 "$TOKEN_FILE" 2>/dev/null || true
  log "Generated new gateway token"
fi
export MOLTBOT_TOKEN="$FINAL_TOKEN"

# ---------------------------------------------------------------------------
# Create moltbot.json only if missing/invalid
# ---------------------------------------------------------------------------

write_default_config() {
  # Use Python to generate config with proper JSON handling for env block
  python3 -c "
import json
import os

config = {
  'gateway': {
    'mode': 'local',
    'port': ${MOLTBOT_PORT:-18789},
    'bind': '${MOLTBOT_BIND:-lan}',
    'auth': {
      'mode': 'token',
      'token': '$FINAL_TOKEN'
    },
    'controlUi': {
      'allowInsecureAuth': True
    }
  },
  'browser': {
    'enabled': True,
    'headless': True,
    'noSandbox': True
  },
  'agents': {
    'defaults': {
      'workspace': '/config/workspace'
    }
  }
}

# Add env block with API keys if present
env_block = {}
for key in ['ANTHROPIC_API_KEY', 'OPENAI_API_KEY', 'OPENROUTER_API_KEY']:
  value = os.environ.get(key)
  if value:
    env_block[key] = value

if env_block:
  config['env'] = env_block

with open('$CONFIG_PATH', 'w') as f:
  json.dump(config, f, indent=2)
"
  chown "$PUID:$PGID" "$CONFIG_PATH" 2>/dev/null || true
  chmod 664 "$CONFIG_PATH" 2>/dev/null || true
}

if [ ! -f "$CONFIG_PATH" ]; then
  log "Creating initial moltbot.json"
  write_default_config
else
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 -c "import json; json.load(open('$CONFIG_PATH'))" 2>/dev/null; then
      bad="$CONFIG_PATH.bad.$(date +%s)"
      log "Invalid moltbot.json detected, backing up to $bad"
      mv "$CONFIG_PATH" "$bad"
      write_default_config
    else
      # Ensure gateway.mode is set (required for gateway command)
      if ! python3 -c "import json; c=json.load(open('$CONFIG_PATH')); assert c.get('gateway',{}).get('mode')" 2>/dev/null; then
        log "Patching moltbot.json: adding gateway.mode=local"
        python3 -c "
import json
with open('$CONFIG_PATH', 'r') as f:
    config = json.load(f)
if 'gateway' not in config:
    config['gateway'] = {}
config['gateway']['mode'] = 'local'
config['gateway'].setdefault('port', ${MOLTBOT_PORT:-18789})
config['gateway'].setdefault('bind', '${MOLTBOT_BIND:-lan}')
with open('$CONFIG_PATH', 'w') as f:
    json.dump(config, f, indent=2)
"
        chown "$PUID:$PGID" "$CONFIG_PATH" 2>/dev/null || true
        chmod 664 "$CONFIG_PATH" 2>/dev/null || true
      else
        log "Existing moltbot.json detected – leaving untouched"
      fi
    fi
  else
    log "WARNING: python3 not found; skipping moltbot.json validation"
  fi
fi

# ---------------------------------------------------------------------------
# Inject API keys from environment into moltbot.json if present
# ---------------------------------------------------------------------------

if [ -f "$CONFIG_PATH" ] && command -v python3 >/dev/null 2>&1; then
  python3 -c "
import json
import os

with open('$CONFIG_PATH', 'r') as f:
    config = json.load(f)

# Create env block if it doesn't exist
if 'env' not in config:
    config['env'] = {}

# Add API keys from environment if set and not already in config
api_keys = ['ANTHROPIC_API_KEY', 'OPENAI_API_KEY', 'OPENROUTER_API_KEY']
added_keys = []
for key in api_keys:
    env_value = os.environ.get(key)
    if env_value and key not in config['env']:
        config['env'][key] = env_value
        added_keys.append(key)

# Only write if we added something
if added_keys:
    with open('$CONFIG_PATH', 'w') as f:
        json.dump(config, f, indent=2)
" 2>/dev/null || true
  chown "$PUID:$PGID" "$CONFIG_PATH" 2>/dev/null || true
  chmod 664 "$CONFIG_PATH" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# XDG config directory symlinks
# ---------------------------------------------------------------------------
if [ ! -e "/config/moltbot" ]; then
  ln -sf .clawdbot /config/moltbot
  log "Created symlink: /config/moltbot -> .clawdbot"
fi
if [ ! -e "/config/clawdbot" ]; then
  ln -sf .clawdbot /config/clawdbot
  log "Created symlink: /config/clawdbot -> .clawdbot"
fi

# ---------------------------------------------------------------------------
# FINAL permission fix (after all config files are created/modified)
# ---------------------------------------------------------------------------
log "Final permission fix before launch..."
chown -R "$PUID:$PGID" "$MOLTBOT_STATE" 2>/dev/null || true
find "$MOLTBOT_STATE" -type d -exec chmod 775 {} \; 2>/dev/null || true
find "$MOLTBOT_STATE" -type f -exec chmod 664 {} \; 2>/dev/null || true

# Verify config file permissions
if [ -f "$CONFIG_PATH" ]; then
  ls -la "$CONFIG_PATH" >&2
fi

# ---------------------------------------------------------------------------
# Start Xvfb (virtual X display for browser automation)
# ---------------------------------------------------------------------------

log "Starting Xvfb virtual display server..."
Xvfb :99 -screen 0 1024x768x24 > /tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 2

if kill -0 "$XVFB_PID" 2>/dev/null; then
  log "✅ Xvfb started (PID: $XVFB_PID, DISPLAY=:99)"
else
  log "⚠️  Xvfb failed to start, browser automation may not work"
fi

# ---------------------------------------------------------------------------
# Launch Moltbot (via wrapper so HOME is ALWAYS /config)
# ---------------------------------------------------------------------------

if [ ! -x /usr/local/bin/moltbot ]; then
  log "❌ ERROR: /usr/local/bin/moltbot not found (wrapper missing)"
  exit 1
fi

CMD="/usr/local/bin/moltbot gateway"
log "Executing: $CMD"

gosu "$PUID:$PGID" env \
  HOME=/config \
  XDG_CONFIG_HOME=/config \
  XDG_DATA_HOME=/config \
  XDG_CACHE_HOME=/config/.cache \
  XDG_RUNTIME_DIR=/tmp/moltbot \
  DISPLAY=:99 \
  MOLTBOT_STATE_DIR="$MOLTBOT_STATE" \
  MOLTBOT_TOKEN="$FINAL_TOKEN" \
  PATH="/usr/local/bin:/usr/bin:/bin" \
  ${ANTHROPIC_API_KEY:+ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"} \
  ${OPENAI_API_KEY:+OPENAI_API_KEY="$OPENAI_API_KEY"} \
  ${OPENROUTER_API_KEY:+OPENROUTER_API_KEY="$OPENROUTER_API_KEY"} \
  sh -lc "umask 0002 && $CMD" &
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