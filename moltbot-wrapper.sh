#!/bin/bash
# Moltbot wrapper
# Absolute rules:
# - Moltbot MUST always run with HOME=/config
# - Moltbot MUST always run as PUID:PGID (default 99:100)
# - No execution path may fall back to /root

set -euo pipefail

# Permissive umask so files created by moltbot are group-writable
umask 0002

# Get PUID/PGID from environment or use Unraid defaults
PUID="${PUID:-99}"
PGID="${PGID:-100}"

# Optional env files first (so they can set MOLTBOT_PORT etc.)
[ -f /etc/environment ] && . /etc/environment || true
[ -f /config/.env ] && . /config/.env || true

# Default command
if [ "$#" -eq 0 ]; then
  set -- gateway
fi

# If running as root, drop privileges to PUID:PGID
if [ "$(id -u)" = "0" ]; then
  exec gosu "$PUID:$PGID" env \
    HOME=/config \
    XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/config \
    XDG_CACHE_HOME=/config/.cache \
    XDG_RUNTIME_DIR=/tmp/moltbot \
    MOLTBOT_STATE_DIR=/config/.clawdbot \
    NODE_ENV="${NODE_ENV:-production}" \
    PATH="/usr/local/bin:/usr/bin:/bin" \
    /usr/local/bin/moltbot-real "$@"
else
  # Already running as non-root, just exec with pinned env
  exec env \
    HOME=/config \
    XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/config \
    XDG_CACHE_HOME=/config/.cache \
    XDG_RUNTIME_DIR=/tmp/moltbot \
    MOLTBOT_STATE_DIR=/config/.clawdbot \
    NODE_ENV="${NODE_ENV:-production}" \
    PATH="/usr/local/bin:/usr/bin:/bin" \
    /usr/local/bin/moltbot-real "$@"
fi