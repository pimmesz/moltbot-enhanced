# Moltbot Unraid

[![Docker Pulls](https://img.shields.io/docker/pulls/pimmesz/moltbot-enhanced)](https://hub.docker.com/r/pimmesz/moltbot-enhanced)
[![GitHub](https://img.shields.io/github/license/pimmesz/moltbot-enhanced)](https://github.com/pimmesz/moltbot-enhanced)

Moltbot AI agent gateway for Unraid servers. Connect AI to messaging platforms like WhatsApp, Telegram, Discord, Slack, and more.

## Features

- Multi-platform messaging (WhatsApp, Telegram, Discord, Slack, Signal, etc.)
- AI agent gateway with WebSocket support
- Interactive CLI configuration
- Unraid compatible (PUID/PGID, non-root, graceful shutdown)
- Persistent state in `/config` volume
- Health monitoring and auto-recovery

### 🤖 AI Butler Capabilities (Enhanced)

This container includes additional tools for smart home automation:

| Category | Tools | Use Cases |
|----------|-------|-----------|
| **🌐 Browser** | Chromium, Playwright, Selenium | Sonos web app control, smart home dashboards |
| **🎵 Audio** | FFmpeg, SoX, codecs | Audio processing, format conversion, streaming |
| **📊 Data** | Pandas, NumPy, jq/yq | Analytics, data processing, JSON/YAML |
| **🔌 IoT** | MQTT, Zeroconf | Smart home protocols, device discovery |
| **💾 Database** | SQLite, PostgreSQL | Data persistence, logging, analytics |
| **🔧 Network** | SSH, curl, DNS tools | Connectivity, debugging, automation |

#### Example: Sonos Control via Browser

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto("http://192.168.1.100:1400")
    # Automate Sonos web interface
```

#### Example: Audio Processing

```bash
# Convert audio format
ffmpeg -i input.flac -codec:a libmp3lame output.mp3

# Analyze audio
sox input.wav -n stats
```

#### Example: Data Analytics

```python
import pandas as pd
# Process server metrics, logs, etc.
df = pd.read_csv('/config/metrics.csv')
print(df.describe())
```

## Quick Start

```bash
docker-compose up -d
docker exec -it moltbot moltbot onboard
```

## Installation

### Unraid (Recommended)

1. Go to **Docker** tab in Unraid
2. Click **Add Container**
3. Toggle **Advanced View**
4. Set **Template repositories** to:
   ```
   https://raw.githubusercontent.com/pimmesz/moltbot-enhanced/main/moltbot-enhanced.xml
   ```
5. Search for "moltbot" and select **moltbot-enhanced**
6. Configure settings (API keys, timezone, etc.)
7. Click **Apply**

The template automatically configures:
- Volume mapping: `/mnt/user/appdata/moltbot` → `/config` (persistent storage)
- Port: `18789` (Gateway WebSocket)
- PUID/PGID: `99`/`100` (Unraid defaults)

After installation:
```bash
docker exec -it moltbot-enhanced moltbot onboard
```

### Docker Compose

```yaml
services:
  moltbot:
    image: pimmesz/moltbot-enhanced:latest
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
  pimmesz/moltbot-enhanced:latest
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PUID` | User ID | `1000` |
| `PGID` | Group ID | `1000` |
| `TZ` | Timezone | `UTC` |
| `MOLTBOT_PORT` | Gateway port | `18789` |
| `MOLTBOT_BIND` | Bind mode (`lan`, `loopback`, or `wan`) | `lan` |
| `MOLTBOT_HOST` | Host IP for Web UI URL (auto-detected if not set) | Auto-detect |
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
- The token is saved in `/config/.clawdbot/.moltbot_token`
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
Repository: pimmesz/moltbot-enhanced:latest
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
rm -rf /mnt/cache/appdata/moltbot/.clawdbot
docker start moltbot
```

## Links

- [Docker Hub](https://hub.docker.com/r/pimmesz/moltbot-enhanced)
- [GitHub](https://github.com/pimmesz/moltbot-enhanced)
- [Moltbot Docs](https://github.com/moltbot/moltbot)

## License

MIT
