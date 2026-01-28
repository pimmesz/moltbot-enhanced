#!/bin/bash
# Wrapper for moltbot binary
# Ensures proper environment and provides graceful shutdown

set -e

# Trap signals for graceful shutdown
cleanup() {
    echo "[moltbot-wrapper] Received shutdown signal, stopping gracefully..."
    kill -TERM "$MOLTBOT_PID" 2>/dev/null || true
    wait "$MOLTBOT_PID" 2>/dev/null || true
    echo "[moltbot-wrapper] Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# Source environment if available
[ -f /etc/environment ] && source /etc/environment
[ -f /config/.env ] && source /config/.env

# Export moltbot-specific vars with defaults
export MOLTBOT_CONFIG_DIR="${MOLTBOT_CONFIG_DIR:-/config/moltbot}"
export MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
export MOLTBOT_BIND="${MOLTBOT_BIND:-lan}"
export HOME="${HOME:-/config}"
export NODE_ENV="${NODE_ENV:-production}"

# Browser settings for Playwright/Puppeteer
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export FIREFOX_PATH=/usr/bin/firefox
export BROWSER_FLAGS="--no-sandbox --disable-gpu --disable-dev-shm-usage"

# Ensure config directory exists
mkdir -p "$MOLTBOT_CONFIG_DIR"

# Run the real moltbot binary in background and wait
/usr/local/bin/moltbot-real "$@" &
MOLTBOT_PID=$!

# Wait for moltbot to exit
wait "$MOLTBOT_PID"
EXIT_CODE=$?

echo "[moltbot-wrapper] Moltbot exited with code $EXIT_CODE"
exit $EXIT_CODE
