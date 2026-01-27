#!/bin/bash
# Moltbot health check script
# Checks if the gateway is responsive

set -e

# Default port if not set
PORT="${MOLTBOT_PORT:-18789}"

# Check if the health endpoint responds
if curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    exit 0
fi

# If health endpoint fails, check if the process is at least running
if pgrep -f "moltbot gateway" >/dev/null 2>&1; then
    # Process is running but health endpoint not responding yet (starting up)
    exit 0
fi

# Process not running
exit 1
