#!/bin/bash
# Chromium wrapper for containerized environments
# Comprehensive fix for Docker/container Chromium startup issues

# Create all necessary directories with full permissions
mkdir -p /tmp/chromium-crash /tmp/chromium-user-data /tmp/chromium-cache /tmp/.X11-unix
chmod 1777 /tmp/chromium-crash /tmp/chromium-user-data /tmp/chromium-cache 2>/dev/null || true

# Use standard chromium executable
CHROME_EXEC="/usr/bin/chromium"
if [ ! -x "$CHROME_EXEC" ]; then
    echo "❌ Chromium executable not found at $CHROME_EXEC" >&2
    exit 1
fi

# Export container-friendly Chromium environment
export CHROME_DEVEL_SANDBOX=0
export CHROMIUM_FLAGS="
  --headless=new
  --no-sandbox
  --disable-dev-shm-usage
  --disable-gpu
  --disable-gpu-sandbox
  --disable-software-rasterizer
  --disable-background-timer-throttling
  --disable-backgrounding-occluded-windows
  --disable-renderer-backgrounding
  --disable-features=TranslateUI,VizDisplayCompositor,AudioServiceOutOfProcess,VizHitTestSurfaceLayer
  --disable-crash-reporter
  --disable-breakpad
  --disable-logging
  --no-crash-upload
  --disable-hang-monitor
  --disable-prompt-on-repost
  --disable-popup-blocking
  --crash-dumps-dir=/tmp/chromium-crash
  --user-data-dir=/tmp/chromium-user-data
  --disk-cache-dir=/tmp/chromium-cache
  --disable-extensions
  --disable-plugins
  --disable-default-apps
  --no-first-run
  --disable-default-browser-check
  --disable-background-networking
  --disable-sync
  --disable-translate
  --metrics-recording-only
  --safebrowsing-disable-auto-update
  --disable-component-update
  --disable-domain-reliability
  --disable-client-side-phishing-detection
  --disable-web-security
  --disable-ipc-flooding-protection
  --max_old_space_size=2048
  --allow-running-insecure-content
  --ignore-certificate-errors
  --ignore-ssl-errors
  --ignore-certificate-errors-spki-list
  --disable-field-trial-config
  --disable-background-media-suspend
  --force-color-profile=srgb
  --autoplay-policy=user-gesture-required
  --disable-audio-output
  --mute-audio
"

# Debug information
echo "🚀 Starting $CHROME_EXEC with container-safe flags..." >&2

# Execute chromium with comprehensive container-safe flags
exec "$CHROME_EXEC" $CHROMIUM_FLAGS "$@"