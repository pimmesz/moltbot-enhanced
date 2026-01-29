#!/bin/bash
# Moltbot wrapper
# Absolute rule:
# - Moltbot MUST always run with HOME=/config
# - No execution path may fall back to /root

set -euo pipefail

log() { echo "[moltbot-wrapper] $*" >&2; }

cleanup() { log "Received shutdown signal"; exit 0; }
trap cleanup SIGTERM SIGINT SIGHUP

# Optional env files first (so they can set MOLTBOT_PORT etc.)
[ -f /etc/environment ] && . /etc/environment || true
[ -f /config/.env ] && . /config/.env || true

# Hard-pin environment (NO exceptions)
export HOME=/config
export XDG_CONFIG_HOME=/config
export XDG_DATA_HOME=/config
export XDG_CACHE_HOME=/config/.cache
export XDG_RUNTIME_DIR=/tmp/moltbot
export MOLTBOT_STATE_DIR=/config/.clawdbot
export NODE_ENV="${NODE_ENV:-production}"
export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

# Ensure required dirs exist
mkdir -p /config/.clawdbot /config/workspace /config/.cache /tmp/moltbot

# Default command
if [ "$#" -eq 0 ]; then
  set -- gateway
fi

# Always run with pinned env
exec env \
  HOME=/config \
  XDG_CONFIG_HOME=/config \
  XDG_DATA_HOME=/config \
  XDG_CACHE_HOME=/config/.cache \
  XDG_RUNTIME_DIR=/tmp/moltbot \
  MOLTBOT_STATE_DIR=/config/.clawdbot \
  PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}" \
  /usr/local/bin/moltbot-real "$@"