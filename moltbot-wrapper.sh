#!/bin/bash
# Wrapper for moltbot binary
# Ensures proper environment and graceful shutdown
# IMPORTANT:
# - Always force HOME=/config so sessions persist
# - Never write to /root
# - Wrapper does NOT gosu (start.sh is the only place that does)

set -e

cleanup() {
    echo "[moltbot-wrapper] Received shutdown signal, stopping gracefully..."
    if [ -n "${MOLTBOT_PID:-}" ]; then
        kill -TERM "$MOLTBOT_PID" 2>/dev/null || true
        wait "$MOLTBOT_PID" 2>/dev/null || true
    fi
    echo "[moltbot-wrapper] Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# Optional env files
[ -f /etc/environment ] && source /etc/environment
[ -f /config/.env ] && source /config/.env

# ------------------------------------------------------------------
# FORCE persistent state under /config (critical)
# ------------------------------------------------------------------
export HOME=/config
export XDG_CONFIG_HOME=/config
export XDG_DATA_HOME=/config
export XDG_CACHE_HOME=/config/.cache

# Moltbot state (must match start.sh)
export MOLTBOT_STATE_DIR="${MOLTBOT_STATE_DIR:-/config/.clawdbot}"
TOKEN_FILE="$MOLTBOT_STATE_DIR/.moltbot_token"

# Auto-load gateway token if not already set
if [ -z "${MOLTBOT_TOKEN:-}" ] && [ -f "$TOKEN_FILE" ]; then
    export MOLTBOT_TOKEN="$(cat "$TOKEN_FILE")"
fi

# Gateway defaults
export MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
export MOLTBOT_BIND="${MOLTBOT_BIND:-lan}"
export NODE_ENV="${NODE_ENV:-production}"

# Browser / sandbox flags (safe defaults)
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export BROWSER_FLAGS="--no-sandbox --disable-gpu --disable-dev-shm-usage"

# Ensure state dir exists (no-op if already created by start.sh)
mkdir -p "$MOLTBOT_STATE_DIR"

# Run the real moltbot binary
/usr/local/bin/moltbot-real "$@" &
MOLTBOT_PID=$!

wait "$MOLTBOT_PID"
EXIT_CODE=$?

echo "[moltbot-wrapper] Moltbot exited with code $EXIT_CODE"
exit "$EXIT_CODE"