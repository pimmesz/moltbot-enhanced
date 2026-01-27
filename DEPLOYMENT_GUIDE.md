# Deployment Guide: Unraid & Local Builds

## ✅ YES - Supports Both Deployment Scenarios

The current setup **fully supports** both:
1. **Unraid Docker deployment** (production)
2. **Local docker-compose build** (development/testing)

---

## 🔑 Key Requirement: MOLTBOT_TOKEN

**IMPORTANT:** Both scenarios **require** the `MOLTBOT_TOKEN` environment variable.

- The gateway authentication cannot be disabled
- Set to any secure string value
- For development: `dev-token` is fine
- For production: use a secure random string

---

## Scenario 1: Unraid Deployment

### Method A: Docker Run Command

```bash
docker run -d \
  --name=moltbot \
  -p 18789:18789 \
  -v /mnt/cache/appdata/moltbot:/config \
  -e PUID=99 \
  -e PGID=100 \
  -e TZ=America/New_York \
  -e MOLTBOT_TOKEN=your-secure-token \
  -e ANTHROPIC_API_KEY=your-api-key \
  --restart=unless-stopped \
  pimmesz/moltbot-unraid:latest
```

### Method B: Unraid Community Applications Template

```xml
Repository: pimmesz/moltbot-unraid:latest
Network Type: Bridge
Port Mapping: 18789 -> 18789 (TCP)
Volume: /mnt/cache/appdata/moltbot -> /config

Environment Variables:
  PUID: 99
  PGID: 100
  TZ: America/New_York
  MOLTBOT_TOKEN: your-secure-token
  ANTHROPIC_API_KEY: your-api-key
```

**Unraid-specific features:**
- ✅ PUID/PGID support for proper file permissions
- ✅ Graceful shutdown handling
- ✅ Health checks integrated
- ✅ Non-root user execution
- ✅ Persistent configuration in `/config`

---

## Scenario 2: Local Development Build

### Setup

```bash
# 1. Clone repository
git clone https://github.com/pimmesz/moltbot-unraid.git
cd moltbot-unraid

# 2. Create .env from example
cp .env.example .env

# 3. Edit .env with your values
nano .env
```

### Required .env Configuration

```bash
# User/Group (use your local IDs for testing)
PUID=1000
PGID=1000

# Timezone
TZ=UTC

# Gateway Token (REQUIRED)
MOLTBOT_TOKEN=dev-token

# AI Provider (at least one)
ANTHROPIC_API_KEY=your-key-here
```

### Build and Run

```bash
# Build for your native platform
docker-compose build

# Start in background
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Stop
docker-compose down
```

**Local development features:**
- ✅ Builds from source (multi-stage build)
- ✅ Native platform builds (ARM64 or AMD64)
- ✅ Fast incremental rebuilds (BuildKit cache)
- ✅ Volume-mapped config for easy editing
- ✅ Health checks work locally

---

## Environment Variables Comparison

| Variable | Unraid | Local | Required |
|----------|--------|-------|----------|
| `PUID` | 99 (nobody) | 1000 (your user) | ✅ Yes |
| `PGID` | 100 (users) | 1000 (your group) | ✅ Yes |
| `TZ` | Your timezone | UTC | Optional |
| `MOLTBOT_TOKEN` | Secure string | `dev-token` | ✅ **Yes** |
| `MOLTBOT_PORT` | 18789 | 18789 | Optional |
| `MOLTBOT_BIND` | lan | lan | Optional |
| `ANTHROPIC_API_KEY` | Your key | Your key | ✅ Yes* |
| `OPENAI_API_KEY` | Your key | Your key | Optional* |

*At least one AI provider API key is required

---

## Configuration Files

Both scenarios use the same configuration structure:

```
/config/
├── .moltbot/
│   ├── moltbot.json          # Main configuration (auto-created)
│   └── credentials/           # Secure credentials storage
└── workspace/                 # Agent workspace directory
```

### Default moltbot.json

```json
{
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "lan"
  },
  "agents": {
    "defaults": {
      "workspace": "/config/workspace"
    }
  }
}
```

**Note:** This file is automatically created on first run with sensible defaults.

---

## Accessing the Gateway

Both scenarios expose the same endpoints:

| Endpoint | URL | Purpose |
|----------|-----|---------|
| Web UI | http://localhost:18789 | Control interface |
| WebSocket | ws://localhost:18789 | Agent gateway |
| Health Check | http://localhost:18789/health | Container health |
| Canvas | http://localhost:18789/__moltbot__/canvas/ | Visual canvas |

**For Unraid:** Replace `localhost` with your server's IP address.

---

## Build Differences

### Unraid (Pre-built Image)

```
Docker Hub → Pull Image → Run Container
  ↓
pimmesz/moltbot-unraid:latest
  ↓
Multi-platform (amd64, arm64)
Pre-compiled, ready to run
~500MB image size
```

**Advantages:**
- ✅ Instant deployment
- ✅ No build time
- ✅ Consistent across all Unraid servers
- ✅ Automatic updates via Docker Hub

### Local (Source Build)

```
GitHub → Clone → Build → Run
  ↓
docker-compose build
  ↓
Multi-stage Dockerfile:
  1. Builder stage (clone, compile, package)
  2. Runtime stage (install, configure)
  ↓
Native platform build
~500MB final image
```

**Advantages:**
- ✅ Latest source code
- ✅ Can modify and test changes
- ✅ Native performance (no emulation)
- ✅ BuildKit cache for fast rebuilds

**Build time:**
- First build: ~2-3 minutes
- Subsequent builds: ~30 seconds (cached)

---

## Platform Support

| Architecture | Unraid | Local Build |
|--------------|--------|-------------|
| AMD64 (x86_64) | ✅ Supported | ✅ Native |
| ARM64 (Apple Silicon, ARM servers) | ✅ Supported | ✅ Native |

**Multi-platform notes:**
- Unraid image includes both architectures
- Local build automatically detects your platform
- No emulation needed on either platform

---

## Troubleshooting

### Issue: Container restarts immediately

**Cause:** Missing or incorrect environment variables

**Solution:**
```bash
# Check logs
docker logs moltbot

# Verify MOLTBOT_TOKEN is set
docker inspect moltbot | grep MOLTBOT_TOKEN

# For local: check .env file
cat .env | grep MOLTBOT_TOKEN
```

### Issue: "Gateway auth token not configured"

**Cause:** `MOLTBOT_TOKEN` environment variable not set

**Solution:**
- **Unraid:** Add `MOLTBOT_TOKEN` variable in template
- **Local:** Add `MOLTBOT_TOKEN=dev-token` to `.env`

### Issue: Permission denied errors

**Cause:** Incorrect PUID/PGID

**Solution:**
```bash
# Check your local user ID
id -u  # PUID
id -g  # PGID

# Update .env or Unraid template
PUID=1000  # Your user ID
PGID=1000  # Your group ID
```

### Issue: Build takes too long

**Cause:** First-time build or no cache

**Solution:**
```bash
# Subsequent builds use cache
docker-compose build  # Much faster

# Clean rebuild only when needed
docker-compose build --no-cache
```

---

## Security Considerations

### Token Security

**For Development (Local):**
```bash
MOLTBOT_TOKEN=dev-token  # Simple, easy to remember
```

**For Production (Unraid):**
```bash
# Generate secure token
openssl rand -hex 32
# Output: a1b2c3d4e5f6...

MOLTBOT_TOKEN=a1b2c3d4e5f6...  # Use in Unraid template
```

### Network Security

Both scenarios support the same security hardening:

```yaml
# Add to docker-compose.yml or Unraid extra parameters
read_only: true
tmpfs:
  - /tmp:rw,noexec,nosuid,size=100m
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETGID
  - SETUID
security_opt:
  - no-new-privileges:true
```

---

## Migration Path

### Unraid → Local Development

```bash
# 1. Clone repository
git clone https://github.com/pimmesz/moltbot-unraid.git

# 2. Copy your Unraid config (optional)
scp -r root@unraid:/mnt/cache/appdata/moltbot/config ./config/

# 3. Create .env with same values as Unraid
cp .env.example .env
# Edit with your Unraid environment values

# 4. Build and run
docker-compose up --build -d
```

### Local Development → Unraid

```bash
# 1. Test locally first
docker-compose up -d

# 2. Once working, use pre-built image on Unraid
Repository: pimmesz/moltbot-unraid:latest

# 3. Copy your local .env values to Unraid template
```

---

## Verification Checklist

### Both Scenarios Should Show:

```bash
✅ Container status: Up (healthy)
✅ Gateway listening on ws://0.0.0.0:18789
✅ Canvas mounted
✅ Heartbeat started
✅ Browser service ready
✅ Health check: http://localhost:18789/health → 200 OK
```

### Test Commands

```bash
# Check container status
docker ps | grep moltbot

# Check health endpoint
curl -sf http://localhost:18789/health

# View configuration
cat config/.moltbot/moltbot.json

# Check logs
docker logs -f moltbot
```

---

## Summary

| Feature | Unraid | Local Build | Status |
|---------|--------|-------------|--------|
| Deployment | Docker Hub image | Source build | ✅ Both work |
| PUID/PGID support | ✅ | ✅ | Identical |
| Multi-platform | ✅ | ✅ | Identical |
| Health checks | ✅ | ✅ | Identical |
| Configuration | ENV vars | ENV vars (.env) | Identical |
| Token requirement | **Required** | **Required** | **Same** |
| Build time | 0 (pre-built) | 2-3 min | - |
| Setup complexity | Low | Medium | - |
| Customization | Limited | Full | - |

**Conclusion:** ✅ **Fully supports both Unraid and local development** with identical functionality and requirements.
