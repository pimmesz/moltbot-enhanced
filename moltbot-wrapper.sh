#!/bin/bash
# Wrapper for moltbot binary
# Ensures proper environment and logging

set -e

# Source environment if available
[ -f /etc/environment ] && source /etc/environment

# Export moltbot-specific vars
export MOLTBOT_CONFIG_DIR="${MOLTBOT_CONFIG_DIR:-/config/moltbot}"
export MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
export MOLTBOT_BIND="${MOLTBOT_BIND:-lan}"

# Ensure config directory exists
mkdir -p "$MOLTBOT_CONFIG_DIR"

# Run the real moltbot binary
exec /usr/local/bin/moltbot-real "$@"
