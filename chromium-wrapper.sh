#!/bin/bash
# Chromium wrapper for containerized environments
# Comprehensive fix for Docker/container Chromium startup issues

# Create all necessary directories with full permissions
mkdir -p /tmp/chromium-crash /tmp/chromium-user-data /tmp/chromium-cache /tmp/.X11-unix
chmod 1777 /tmp/chromium-crash /tmp/chromium-user-data /tmp/chromium-cache /tmp/.X11-unix 2>/dev/null || true

# Export container-friendly Chromium environment
export CHROME_DEVEL_SANDBOX=0
export CHROMIUM_FLAGS="
  --headless
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
  --disable-blink-features=AutomationControlled
  --enable-logging=stderr
  --log-level=0
"

# Execute chromium with comprehensive container-safe flags
exec /usr/bin/chromium $CHROMIUM_FLAGS "$@" 2>/dev/null