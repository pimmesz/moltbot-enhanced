# Moltbot Unraid

[![Docker Pulls](https://img.shields.io/docker/pulls/pimmesz/moltbot-unraid)](https://hub.docker.com/r/pimmesz/moltbot-unraid)
[![GitHub](https://img.shields.io/github/license/pimmesz/moltbot-unraid)](https://github.com/pimmesz/moltbot-unraid)

Moltbot AI agent gateway for Unraid servers. Connect AI to messaging platforms like WhatsApp, Telegram, Discord, Slack, and more.

## Features

- **Multi-Platform Messaging**: Connect to WhatsApp, Telegram, Discord, Slack, Signal, and more
- **AI Agent Gateway**: WebSocket-based gateway for AI agent communication
- **Unraid Compatible**: Follows Unraid conventions (PUID/PGID, non-root user, graceful shutdown)
- **Persistent State**: All configuration stored in `/config` volume
- **Health Monitoring**: Built-in health check endpoint

## Requirements

- Unraid 6.x or Docker-compatible system
- Network access for messaging platform APIs
- API keys for your chosen AI providers (Anthropic, OpenAI, etc.)

## Quick Start

### Docker Run

```bash
docker run -d \
  --name moltbot \
  -p 18789:18789 \
  -v /mnt/cache/appdata/moltbot:/config \
  -e PUID=99 \
  -e PGID=100 \
  -e TZ=America/New_York \
  -e MOLTBOT_TOKEN=your-secure-token \
  -e ANTHROPIC_API_KEY=your-key-here \
  pimmesz/moltbot-unraid:latest
```

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
      # Required: Gateway authentication token
      - MOLTBOT_TOKEN=your-secure-token
      # Required: At least one AI provider API key
      - ANTHROPIC_API_KEY=your-key-here
      # Optional: Additional providers
      # - OPENAI_API_KEY=your-key-here
      # - OPENROUTER_API_KEY=your-key-here
```

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `PUID` | User ID for file permissions | `99` (Unraid default) |
| `PGID` | Group ID for file permissions | `100` (Unraid default) |
| `MOLTBOT_TOKEN` | Gateway authentication token | `dev-token` or secure random string |
| `ANTHROPIC_API_KEY` | Anthropic API key (or another provider) | `sk-ant-...` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | `UTC` |
| `MOLTBOT_PORT` | Gateway port | `18789` |
| `MOLTBOT_BIND` | Bind mode (`loopback`, `lan`, `auto`) | `lan` |
| `MOLTBOT_CMD` | Override the startup command | (gateway) |

### AI Provider API Keys

Configure at least one provider:

| Variable | Provider |
|----------|----------|
| `ANTHROPIC_API_KEY` | Anthropic Claude |
| `OPENAI_API_KEY` | OpenAI |
| `OPENROUTER_API_KEY` | OpenRouter |
| `GEMINI_API_KEY` | Google Gemini |

## Volumes

| Container Path | Description |
|---------------|-------------|
| `/config` | Persistent configuration and state |

The `/config` volume contains:
- `.moltbot/` - Moltbot configuration and credentials
- `workspace/` - Agent workspace directory

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 18789 | HTTP/WebSocket | Gateway API and WebSocket |

## Unraid Template Settings

For Unraid Community Applications, use these settings:

```
Repository: pimmesz/moltbot-unraid:latest
Network Type: Bridge
Port Mapping: 18789 -> 18789 (TCP)
Volume: /mnt/cache/appdata/moltbot -> /config
Variable: PUID = 99
Variable: PGID = 100
Variable: TZ = America/New_York
Variable: MOLTBOT_TOKEN = (your secure token)
Variable: ANTHROPIC_API_KEY = (your key)
```

## Post-Installation Setup

After starting the container:

1. **Access the Gateway**: Open `http://your-server:18789` in a browser
2. **Check Health**: Run `docker exec moltbot moltbot health`
3. **Configure Channels**: Run `docker exec -it moltbot moltbot channels add`
4. **View Status**: Run `docker exec moltbot moltbot status`

### WhatsApp Setup

```bash
docker exec -it moltbot moltbot channels login --channel whatsapp
# Scan the QR code with WhatsApp on your phone
```

### Telegram Setup

```bash
docker exec moltbot moltbot channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

### Discord Setup

```bash
docker exec moltbot moltbot channels add --channel discord --token "YOUR_BOT_TOKEN"
```

## Security Hardening (Optional)

For additional security, add these Docker parameters:

```bash
docker run -d \
  --name moltbot \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --cap-drop ALL \
  --cap-add CHOWN \
  --cap-add SETGID \
  --cap-add SETUID \
  --security-opt no-new-privileges:true \
  -p 18789:18789 \
  -v /mnt/cache/appdata/moltbot:/config \
  -e PUID=99 \
  -e PGID=100 \
  -e TZ=America/New_York \
  -e ANTHROPIC_API_KEY=your-key-here \
  pimmesz/moltbot-unraid:latest
```

**Unraid Extra Parameters** (paste in Advanced View):
```
--read-only --tmpfs /tmp:rw,noexec,nosuid,size=100m --cap-drop ALL --cap-add CHOWN --cap-add SETGID --cap-add SETUID --security-opt no-new-privileges:true
```

## CLI Reference

Common commands you can run inside the container:

```bash
# Check gateway health
docker exec moltbot moltbot health

# View status
docker exec moltbot moltbot status

# List configured channels
docker exec moltbot moltbot channels list

# View logs
docker exec moltbot moltbot logs --follow

# Interactive configuration
docker exec -it moltbot moltbot configure

# Run diagnostics
docker exec moltbot moltbot doctor
```

## Troubleshooting

### Container won't start

Check logs:
```bash
docker logs moltbot
```

### Permission errors

Ensure PUID/PGID match your Unraid user:
```bash
# Check file ownership
ls -la /mnt/cache/appdata/moltbot
```

### Network connectivity

Test from inside the container:
```bash
docker exec moltbot curl -sf http://127.0.0.1:18789/health
```

### Reset configuration

Remove config and restart:
```bash
docker stop moltbot
rm -rf /mnt/cache/appdata/moltbot/.moltbot
docker start moltbot
```

### Gateway configuration error

If you see `Gateway start blocked: set gateway.mode=local`, the default config will be created automatically on next restart:
```bash
docker restart moltbot
```

## Links

- **Moltbot Documentation**: https://docs.molt.bot
- **Docker Hub**: https://hub.docker.com/r/pimmesz/moltbot-unraid
- **GitHub**: https://github.com/pimmesz/moltbot-unraid
- **Issues**: https://github.com/pimmesz/moltbot-unraid/issues

## License

MIT License - see [LICENSE](LICENSE) file.

---

**Made with ❤️ for the Unraid community**
