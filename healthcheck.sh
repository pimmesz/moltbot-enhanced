#!/bin/bash
# Health check for moltbot container
# Returns 0 (healthy) or 1 (unhealthy)

MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
TIMEOUT=5

# Check 1: Is moltbot process running?
if ! pgrep -f "node.*moltbot" > /dev/null 2>&1; then
    echo "UNHEALTHY: Moltbot process not running"
    exit 1
fi

# Check 2: Is the port listening?
check_port() {
    # Try multiple methods for compatibility
    if command -v ss > /dev/null 2>&1; then
        ss -tuln 2>/dev/null | grep -q ":$MOLTBOT_PORT "
    elif command -v netstat > /dev/null 2>&1; then
        netstat -tuln 2>/dev/null | grep -q ":$MOLTBOT_PORT "
    elif [ -e "/proc/net/tcp" ]; then
        # Fallback: check /proc/net/tcp (port in hex)
        local hex_port=$(printf '%04X' "$MOLTBOT_PORT")
        grep -qi ":$hex_port" /proc/net/tcp 2>/dev/null
    else
        # Can't check port, assume OK if process is running
        return 0
    fi
}

if ! check_port; then
    echo "UNHEALTHY: Port $MOLTBOT_PORT not listening"
    exit 1
fi

# Check 3: HTTP health endpoint (optional, with timeout)
if command -v curl > /dev/null 2>&1; then
    # Try health endpoint first, fall back to root
    if curl -sf --max-time "$TIMEOUT" "http://localhost:$MOLTBOT_PORT/health" > /dev/null 2>&1; then
        echo "HEALTHY: Health endpoint responded"
        exit 0
    elif curl -sf --max-time "$TIMEOUT" "http://localhost:$MOLTBOT_PORT/" > /dev/null 2>&1; then
        echo "HEALTHY: Root endpoint responded"
        exit 0
    fi
    # HTTP check failed, but process is running and port is open
    # This is acceptable - moltbot might not have HTTP health endpoint
fi

# Process running + port open = healthy enough
echo "HEALTHY: Process running, port $MOLTBOT_PORT open"
exit 0
