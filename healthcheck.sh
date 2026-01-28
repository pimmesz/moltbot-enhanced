#!/bin/bash
# Health check for moltbot container

# Check if moltbot process is running
if ! pgrep -f "node.*moltbot" > /dev/null; then
    exit 1
fi

# Check if port 18789 is listening
if ! netstat -tuln 2>/dev/null | grep -q ":18789 "; then
    # Fallback for systems without netstat
    if ! ss -tuln 2>/dev/null | grep -q ":18789 "; then
        exit 1
    fi
fi

# Check if moltbot responds
if ! curl -sf http://localhost:18789/health > /dev/null 2>&1; then
    # If health endpoint doesn't exist, just check port
    exit 0
fi

exit 0
