#!/bin/bash
# Check Moltbot status
# Run with: bash scripts/check-status.sh

set -e

CONTAINER_NAME="moltbot"

echo "=================================="
echo "🤖 Moltbot Status Check"
echo "=================================="
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container '$CONTAINER_NAME' not found"
    echo ""
    echo "To create it, run:"
    echo "  docker-compose up -d"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container is stopped"
    echo ""
    echo "To start it, run:"
    echo "  docker-compose start"
    echo ""
    echo "To view logs:"
    echo "  docker-compose logs"
    exit 1
fi

echo "✅ Container is running"
echo ""

# Check health
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME 2>/dev/null || echo "none")
if [ "$HEALTH" = "healthy" ]; then
    echo "✅ Health check: healthy"
elif [ "$HEALTH" = "starting" ]; then
    echo "⏳ Health check: starting (wait a moment...)"
elif [ "$HEALTH" = "unhealthy" ]; then
    echo "❌ Health check: unhealthy"
else
    echo "ℹ️  Health check: not configured"
fi
echo ""

# Check if port is accessible
PORT=$(docker port $CONTAINER_NAME 18789 2>/dev/null | cut -d: -f2 || echo "18789")
if curl -sf http://localhost:${PORT}/health >/dev/null 2>&1; then
    echo "✅ Gateway is responding on port $PORT"
else
    echo "⚠️  Gateway not responding on port $PORT"
    echo "   (May still be starting up...)"
fi
echo ""

# Get auto-generated token
if docker exec $CONTAINER_NAME test -f /config/.moltbot/.moltbot_token 2>/dev/null; then
    TOKEN=$(docker exec $CONTAINER_NAME cat /config/.moltbot/.moltbot_token 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        echo "🔑 Auto-generated token:"
        echo "   $TOKEN"
    fi
else
    echo "ℹ️  Using custom MOLTBOT_TOKEN from environment"
fi
echo ""

# Check for API keys
echo "🔑 AI Provider Keys:"
if docker exec $CONTAINER_NAME printenv | grep -q "ANTHROPIC_API_KEY=sk-"; then
    echo "   ✅ Anthropic API key configured"
else
    echo "   ❌ Anthropic API key missing"
fi

if docker exec $CONTAINER_NAME printenv | grep -q "OPENAI_API_KEY=sk-"; then
    echo "   ✅ OpenAI API key configured"
fi

if docker exec $CONTAINER_NAME printenv | grep -q "OPENROUTER_API_KEY=sk-"; then
    echo "   ✅ OpenRouter API key configured"
fi
echo ""

# Show recent logs
echo "📝 Recent logs (last 10 lines):"
echo "---"
docker logs --tail=10 $CONTAINER_NAME 2>&1 | sed 's/^/   /'
echo ""

echo "=================================="
echo "Quick commands:"
echo ""
echo "  View all logs:"
echo "    docker logs -f $CONTAINER_NAME"
echo ""
echo "  Restart container:"
echo "    docker-compose restart"
echo ""
echo "  Access control panel:"
echo "    http://localhost:18789"
echo ""
echo "  Run health check:"
echo "    docker exec $CONTAINER_NAME moltbot health"
echo "=================================="
