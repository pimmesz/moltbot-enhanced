#!/bin/bash
# Test browser automation functionality
# Use this script to validate Chromium wrapper and CDP service

set -e

echo "🔍 Testing browser automation setup..."

echo "1. Testing Chromium wrapper..."
if /usr/local/bin/chromium-wrapper --version >/dev/null 2>&1; then
    echo "✅ Chromium wrapper executable"
else
    echo "❌ Chromium wrapper failed"
    exit 1
fi

echo "2. Testing CDP service startup..."
timeout 10s /usr/local/bin/chromium-wrapper --headless --no-sandbox --remote-debugging-port=18888 --disable-gpu &
CHROME_PID=$!
sleep 3

if curl -s http://localhost:18888/json/version >/dev/null 2>&1; then
    echo "✅ CDP service responsive on port 18888"
    kill $CHROME_PID 2>/dev/null || true
else
    echo "❌ CDP service failed to start"
    kill $CHROME_PID 2>/dev/null || true
    exit 1
fi

echo "3. Testing environment variables..."
if [ "$PUPPETEER_EXECUTABLE_PATH" = "/usr/local/bin/chromium-wrapper" ]; then
    echo "✅ PUPPETEER_EXECUTABLE_PATH correctly set"
else
    echo "❌ PUPPETEER_EXECUTABLE_PATH: $PUPPETEER_EXECUTABLE_PATH (should be /usr/local/bin/chromium-wrapper)"
    exit 1
fi

echo "4. Testing required directories..."
for dir in /tmp/chromium-crash /tmp/chromium-user-data /dev/shm; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        echo "✅ $dir exists and writable"
    else
        echo "❌ $dir missing or not writable"
        exit 1
    fi
done

echo ""
echo "🎉 Browser automation setup test PASSED!"
echo "If Moltbot browser service still fails, try restarting the gateway."