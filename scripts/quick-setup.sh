#!/bin/bash
# Quick setup script for Moltbot Unraid
# Run with: bash scripts/quick-setup.sh

set -e

echo "=================================="
echo "🤖 Moltbot Unraid Quick Setup"
echo "=================================="
echo ""

# Check if .env exists
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists."
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Copy example
cp .env.example .env
echo "✅ Created .env file"
echo ""

# Get PUID/PGID
echo "📋 Detecting your user ID and group ID..."
PUID=$(id -u)
PGID=$(id -g)
echo "   PUID: $PUID"
echo "   PGID: $PGID"
echo ""

# Update .env
sed -i.bak "s/PUID=.*/PUID=$PUID/" .env
sed -i.bak "s/PGID=.*/PGID=$PGID/" .env
rm -f .env.bak
echo "✅ Updated PUID and PGID in .env"
echo ""

# Get timezone
echo "🌍 Detecting timezone..."
if [ -f /etc/timezone ]; then
    TZ=$(cat /etc/timezone)
elif [ -L /etc/localtime ]; then
    TZ=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
else
    TZ="UTC"
fi
echo "   Timezone: $TZ"
sed -i.bak "s|TZ=.*|TZ=$TZ|" .env
rm -f .env.bak
echo "✅ Updated timezone in .env"
echo ""

# Prompt for API key
echo "🔑 AI Provider API Key"
echo ""
echo "You need at least one AI provider API key."
echo "Recommended: Anthropic (Claude)"
echo ""
read -p "Enter your Anthropic API key (or press Enter to skip): " api_key
if [ -n "$api_key" ]; then
    sed -i.bak "s/ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=$api_key/" .env
    rm -f .env.bak
    echo "✅ Updated ANTHROPIC_API_KEY in .env"
else
    echo "⚠️  No API key provided. You'll need to add it manually to .env"
fi
echo ""

echo "=================================="
echo "✅ Docker Setup Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo ""
echo "1. If you skipped the API key, edit .env and add it:"
echo "   nano .env"
echo ""
echo "2. Start the container:"
echo "   docker-compose up -d"
echo ""
echo "3. Check status and get your auto-generated token:"
echo "   bash scripts/check-status.sh"
echo ""
echo "4. Run moltbot's built-in setup wizard:"
echo "   docker exec -it moltbot moltbot onboard"
echo ""
echo "5. Access the control panel:"
echo "   http://localhost:18789"
echo ""
echo "=================================="
echo ""
echo "💡 Tip: After the container starts, moltbot has powerful"
echo "   built-in commands for configuration and management:"
echo "   - moltbot onboard    (interactive setup wizard)"
echo "   - moltbot configure  (credentials & devices)"
echo "   - moltbot doctor     (health checks & fixes)"
echo "=================================="
