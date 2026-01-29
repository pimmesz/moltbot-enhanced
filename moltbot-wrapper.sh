#!/bin/bash
# Wrapper for moltbot binary
# Forces state/config to /config (persistent) even when "docker exec" runs as root
set -euo pipefail

cleanup() {
  echo "[moltbot-wrapper] Received shutdown signal, forwarding to Moltbot..."
  # With exec, Moltbot is PID 1, so just exit and let Docker deliver the signal.
  # (This trap is mostly here for logs / clarity.)
  exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

# Source env if available
[ -f /etc/environment ] && . /etc/environment || true
[ -f /config/.env ] && . /config/.env || true

# ALWAYS pin Moltbot state to /config (so "docker exec" doesn't use /root)
export HOME=/config
export XDG_CONFIG_HOME=/config
export XDG_DATA_HOME=/config
export XDG_CACHE_HOME=/config/.cache

# If Moltbot respects a state dir env var, set it too (harmless if ignored)
export MOLTBOT_STATE_DIR=/config/.clawdbot

# Defaults
export MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
export MOLTBOT_BIND="${MOLTBOT_BIND:-lan}"
export NODE_ENV="${NODE_ENV:-production}"

# Browser knobs (only if you actually need browser automation)
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export BROWSER_FLAGS="--no-sandbox --disable-gpu --disable-dev-shm-usage"

# Ensure persistent dirs exist (matches your start.sh)
mkdir -p /config/.clawdbot /config/workspace /config/.cache

# Default command: gateway
if [ "$#" -eq 0 ]; then
  set -- gateway
fi

# Run Moltbot as PID 1 (important for reliable restarts + signal handling)
exec /usr/local/bin/moltbot-real "$@"