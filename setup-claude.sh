#!/bin/bash
# Setup Claude CLI for Moltbot
# This script helps configure Claude CLI to use your Max subscription

echo "🤖 Claude CLI Setup for Moltbot"
echo "================================="

# Check if Claude CLI is available
if ! command -v claude >/dev/null 2>&1; then
    echo "❌ Claude CLI not found. Install with:"
    echo "curl -fsSL https://claude.ai/install.sh | bash"
    exit 1
fi

echo "✅ Claude CLI found: $(claude --version 2>/dev/null || echo 'version unknown')"

echo ""
echo "🔑 Next steps:"
echo "1. Login to your Claude account:"
echo "   claude auth login"
echo ""
echo "2. Setup token for API access:"
echo "   claude setup-token"
echo ""
echo "3. Test the connection:"
echo "   claude chat 'Hello, this is a test message'"
echo ""
echo "4. Once working, you can integrate with Moltbot using Claude CLI commands"
echo ""
echo "💡 This allows using your Claude Max subscription for unlimited conversations"
echo "   instead of pay-per-token API access!"

# Check if already authenticated
if claude auth status >/dev/null 2>&1; then
    echo ""
    echo "✅ Already authenticated with Claude!"
    echo "Ready to use Claude Max subscription with Moltbot."
fi