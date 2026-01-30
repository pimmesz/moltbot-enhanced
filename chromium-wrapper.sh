#!/bin/bash
# Chromium wrapper for containerized environments
# Fixes common Docker/container Chromium startup issues

# Create necessary directories
mkdir -p /tmp/chromium-crash /tmp/chromium-user-data

# Export container-friendly Chromium environment
export CHROME_DEVEL_SANDBOX=0
export CHROMIUM_FLAGS="
  --headless
  --no-sandbox
  --disable-dev-shm-usage
  --disable-gpu
  --disable-software-rasterizer
  --disable-background-timer-throttling
  --disable-backgrounding-occluded-windows
  --disable-renderer-backgrounding
  --disable-features=TranslateUI,VizDisplayCompositor
  --disable-crash-reporter
  --crash-dumps-dir=/tmp/chromium-crash
  --user-data-dir=/tmp/chromium-user-data
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
"

# Execute chromium with container-safe flags
exec /usr/bin/chromium $CHROMIUM_FLAGS "$@"