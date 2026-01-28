#!/bin/bash
set -e

# Unraid compatibility - set user/group
export UID=${PUID:-99}
export GID=${PGID:-100}

# Ensure user exists
if ! id -u moltbot > /dev/null 2>&1; then
    groupadd -g "$GID" moltbot 2>/dev/null || true
    useradd -u "$UID" -g "$GID" -s /bin/false moltbot 2>/dev/null || true
fi

# Create directories with proper permissions
mkdir -p /config /tmp/moltbot
chown -R "$UID:$GID" /config /tmp/moltbot

# Run moltbot as the specified user
exec gosu "$UID:$GID" moltbot "$@"
