#!/bin/bash
# Wrapper for moltbot CLI commands
# Ensures all commands run as the correct non-root user

# Get PUID/PGID from environment or use defaults
PUID=${PUID:-99}
PGID=${PGID:-100}

# If already running as the target user, just execute
if [ "$(id -u)" = "$PUID" ]; then
    exec /usr/local/bin/moltbot-real "$@"
fi

# Otherwise, use gosu to run as the correct user
exec gosu "$PUID:$PGID" env HOME=/config /usr/local/bin/moltbot-real "$@"
