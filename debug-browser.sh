#!/bin/bash
# Debug browser automation issues in Moltbot container
# Run this to diagnose CDP service startup problems

echo "🔍 Moltbot Browser Automation Diagnostics"
echo "=========================================="

echo ""
echo "📝 Environment Variables:"
echo "PUPPETEER_EXECUTABLE_PATH: $PUPPETEER_EXECUTABLE_PATH"
echo "CHROME_DEVEL_SANDBOX: $CHROME_DEVEL_SANDBOX"
echo "DISPLAY: $DISPLAY"

echo ""
echo "📁 Directory Permissions:"
for dir in "/tmp/chromium-crash" "/tmp/chromium-user-data" "/dev/shm" "/tmp"; do
    if [ -d "$dir" ]; then
        perm=$(stat -c "%a" "$dir" 2>/dev/null || echo "???")
        owner=$(stat -c "%U:%G" "$dir" 2>/dev/null || echo "???")
        echo "✅ $dir ($perm $owner)"
    else
        echo "❌ $dir (missing)"
    fi
done

echo ""
echo "🔧 Chromium Wrapper Test:"
if [ -x "/usr/local/bin/chromium-wrapper" ]; then
    echo "✅ Wrapper executable exists"
    timeout 5s /usr/local/bin/chromium-wrapper --version 2>/dev/null || echo "❌ Wrapper execution failed"
else
    echo "❌ Wrapper script missing or not executable"
fi

echo ""
echo "🌐 Port 18800 Check:"
if netstat -ln 2>/dev/null | grep -q ":18800"; then
    echo "⚠️  Port 18800 already in use"
else
    echo "✅ Port 18800 available"
fi

echo ""
echo "🚀 CDP Service Test:"
echo "Starting test CDP on port 18890..."
timeout 10s /usr/local/bin/chromium-wrapper --headless --no-sandbox --remote-debugging-port=18890 --disable-gpu 2>/dev/null &
CDP_PID=$!
sleep 3

if curl -s http://localhost:18890/json/version >/dev/null 2>&1; then
    echo "✅ CDP service test PASSED - browser can start"
    kill $CDP_PID 2>/dev/null || true
else
    echo "❌ CDP service test FAILED - browser cannot start"
    kill $CDP_PID 2>/dev/null || true
fi

echo ""
echo "📊 Summary:"
echo "If all tests pass but Moltbot browser service fails, the issue is likely:"
echo "- Moltbot's browser detection cache needs clearing"
echo "- Browser service process conflicts"
echo "- Try: moltbot gateway restart"