#!/bin/bash
# Fix browser environment variables for Moltbot
# This ensures the correct Chromium executable path is used

# Force the correct Puppeteer executable path
export PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chromium-wrapper

# Execute any additional commands passed to this script
exec "$@"