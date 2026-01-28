# Moltbot Unraid

[![Docker Pulls](https://img.shields.io/docker/pulls/pimmesz/moltbot-unraid)](https://hub.docker.com/r/pimmesz/moltbot-unraid)
[![GitHub](https://img.shields.io/github/license/pimmesz/moltbot-unraid)](https://github.com/pimmesz/moltbot-unraid)

Moltbot AI agent gateway for Unraid servers. Connect AI to messaging platforms like WhatsApp, Telegram, Discord, Slack, and more.

## Features

- Multi-platform messaging (WhatsApp, Telegram, Discord, Slack, Signal, etc.)
- AI agent gateway with WebSocket support
- Interactive CLI configuration
- Unraid compatible (PUID/PGID, non-root, graceful shutdown)
- Persistent state in `/config` volume
- Health monitoring and auto-recovery

## Quick Start

```bash
docker-compose up -d
docker exec -it moltbot moltbot onboard
```

## Installation

### Docker Compose

```yaml
services:
  moltbot:
    image: pimmesz/moltbot-unraid:latest
    container_name: moltbot
    restart: unless-stopped
    ports:
      - "18789:18789"
    volumes:
      - /mnt/cache/appdata/moltbot:/config
    environment:
      - PUID=99
      - PGID=100
      - TZ=America/New_York
      - ANTHROPIC_API_KEY=your-key-here
```

### Docker Run

```bash
docker run -d \
  --name moltbot \
  -p 18789:18789 \
  -v /mnt/cache/appdata/moltbot:/config \
  -e PUID=99 \
  -e PGID=100 \
  -e TZ=America/New_York \
  -e ANTHROPIC_API_KEY=your-key-here \
  pimmesz/moltbot-unraid:latest
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PUID` | User ID | `1000` |
| `PGID` | Group ID | `1000` |
| `TZ` | Timezone | `UTC` |
| `MOLTBOT_PORT` | Gateway port | `18789` |
| `MOLTBOT_BIND` | Bind mode | `lan` |
| `ANTHROPIC_API_KEY` | Anthropic API key | - |
| `OPENAI_API_KEY` | OpenAI API key | - |
| `OPENROUTER_API_KEY` | OpenRouter API key | - |
| `GEMINI_API_KEY` | Google Gemini API key | - |

## Web UI Access

After starting the container, check the logs for the tokenized URL:

```bash
docker logs moltbot
```

Look for a line like:

```
Web UI (copy and paste this URL):
  http://192.168.2.96:18789/?token=88d1aa4c3122b0d81616e3d641ffa307be4f41ff984bed17c53a1ae3e8626980
```

Copy the entire URL (including the `?token=...` part) and paste it into your browser.

**Why is a token needed?**
- The gateway requires authentication to prevent unauthorized access
- A secure token is auto-generated on first startup
- The token is saved in `/config/.moltbot/.moltbot_token`
- Without the token in the URL, you'll see "unauthorized: gateway token mismatch"

**Alternative:** Paste the token manually in the Control UI settings if you access `http://YOUR_IP:18789` without the token parameter.

## Configuration

### Interactive Setup

```bash
docker exec -it moltbot moltbot onboard
```

### Add Channels

```bash
docker exec -it moltbot moltbot channels login
```

### Health Check

```bash
docker exec moltbot moltbot doctor
```

### View Status

```bash
docker exec moltbot moltbot status
```

## Volumes

| Path | Purpose |
|------|---------|
| `/config` | Configuration and state |

## Ports

| Port | Purpose |
|------|---------|
| `18789` | Gateway (HTTP/WebSocket) |

## Unraid Template

```
Repository: pimmesz/moltbot-unraid:latest
Network: Bridge
Port: 18789
Volume: /mnt/cache/appdata/moltbot -> /config
PUID: 99
PGID: 100
TZ: America/New_York
ANTHROPIC_API_KEY: (your-key)
```

## Troubleshooting

### View Logs

```bash
docker logs -f moltbot
```

### Check Health

```bash
docker exec moltbot moltbot doctor
```

### Reset Config

```bash
docker stop moltbot
rm -rf /mnt/cache/appdata/moltbot/.moltbot
docker start moltbot
```

## Links

- [Docker Hub](https://hub.docker.com/r/pimmesz/moltbot-unraid)
- [GitHub](https://github.com/pimmesz/moltbot-unraid)
- [Moltbot Docs](https://github.com/moltbot/moltbot)

## License

MIT
