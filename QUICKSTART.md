# 🚀 Moltbot Unraid - Quick Start Guide

## 🎯 Two Ways to Set Up Moltbot

### Option 1: Web UI (Recommended for Unraid) 🌐

**Perfect if you prefer clicking buttons over typing commands!**

1. **Start the container:**
   ```bash
   docker-compose up -d
   ```

2. **Open the Onboarding Web UI in your browser:**
   ```
   http://localhost:18790
   ```
   Or on Unraid: `http://YOUR-UNRAID-IP:18790`

3. **Click "Full Onboarding"**

4. **Follow the prompts** in the web terminal

5. **Done!** 🎉

### Option 2: Command Line (For Terminal Users) 💻

1. **Start the container:**
   ```bash
   docker-compose up -d
   ```

2. **Run the onboarding wizard:**
   ```bash
   docker exec -it moltbot moltbot onboard
   ```

3. **Follow the prompts**

4. **Done!** 🎉

**Both methods are identical - use whichever you prefer!**

---

## 🔑 Finding Your Auto-Generated Token

The token is automatically generated on first start. To find it:

### Method 1: Check Logs
```bash
docker logs moltbot | grep "AUTO-GENERATED"
```

### Method 2: Use Status Script
```bash
bash scripts/check-status.sh
```

### Method 3: Read Token File
```bash
docker exec moltbot cat /config/.moltbot/.moltbot_token
```

---

## 🌐 Accessing the Interfaces

Once running, you have access to:

| Service | URL | Purpose |
|---------|-----|---------|
| **Onboarding Web UI** | `http://localhost:18790` | Setup wizard (web terminal) |
| **Gateway Control Panel** | `http://localhost:18789` | Main control interface |

---

## ⚡ Quick Commands

### Check Status
```bash
bash scripts/check-status.sh
```

Shows:
- ✅ Container health
- 🔑 Auto-generated token
- 🔑 API key status
- 📝 Recent logs

### View Logs
```bash
docker logs -f moltbot
```

### Restart
```bash
docker-compose restart
```

### Stop
```bash
docker-compose down
```

### Rebuild (if needed)
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

---

## 🆘 Troubleshooting

### Web UI Not Loading (http://localhost:18790)

1. **Check if container is running:**
   ```bash
   docker ps | grep moltbot
   ```

2. **Check if onboarding server started:**
   ```bash
   docker logs moltbot | grep "Onboarding UI"
   ```

3. **Check the onboarding UI logs:**
   ```bash
   docker exec moltbot cat /tmp/onboarding-ui.log
   ```

4. **Restart the container:**
   ```bash
   docker-compose restart
   ```

### Gateway Not Accessible (http://localhost:18789)

1. **Check the logs for errors:**
   ```bash
   docker logs moltbot
   ```

2. **Verify the token:**
   ```bash
   docker exec moltbot cat /config/.moltbot/.moltbot_token
   ```

3. **Run health check:**
   ```bash
   docker exec moltbot moltbot doctor
   ```

### "No AI Provider API Key" Warning

This is just a warning. The container will start, but AI features won't work until you add a key.

**To fix:** Add one of these to your `.env` file:
```bash
ANTHROPIC_API_KEY=your-key-here
# or
OPENAI_API_KEY=your-key-here
# or
OPENROUTER_API_KEY=your-key-here
```

Then restart:
```bash
docker-compose restart
```

### Build Taking Too Long (15+ minutes)

**This is normal for the first build!**

- Building for 2 platforms (amd64 + arm64)
- Compiling moltbot from source (~1000 packages)
- Building onboarding UI

**Subsequent builds:** 3-5 minutes (cache kicks in)

---

## 📝 Configuration Files

### `.env` (Docker Configuration)
```bash
# User/Group IDs
PUID=99                    # Unraid default (or use: id -u)
PGID=100                   # Unraid default (or use: id -g)

# Timezone
TZ=UTC                     # e.g., America/New_York

# AI Provider (at least one required)
ANTHROPIC_API_KEY=         # Recommended
# OPENAI_API_KEY=
# OPENROUTER_API_KEY=
# GEMINI_API_KEY=

# Optional: Custom token (auto-generated if not set)
# MOLTBOT_TOKEN=

# Optional: Custom port
# MOLTBOT_PORT=18789

# Optional: Bind mode
# MOLTBOT_BIND=lan
```

### `moltbot.json` (Moltbot Configuration)
Auto-generated at `/config/.moltbot/moltbot.json`

Default:
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

---

## 🎓 Next Steps After Setup

### 1. Add Messaging Channels

**Web UI Method:**
```
1. Open http://localhost:18790
2. Click "Add Channels"
3. Follow QR code for WhatsApp
```

**CLI Method:**
```bash
docker exec -it moltbot moltbot channels login
```

### 2. Configure Credentials

**Web UI Method:**
```
1. Open http://localhost:18790
2. Click "Configure"
3. Add API keys and credentials
```

**CLI Method:**
```bash
docker exec -it moltbot moltbot configure
```

### 3. Run Health Check

**Web UI Method:**
```
1. Open http://localhost:18790
2. Click "Health Check"
3. Review results
```

**CLI Method:**
```bash
docker exec moltbot moltbot doctor
```

### 4. Check Status

**Web UI Method:**
```
1. Open http://localhost:18790
2. Click "Status"
```

**CLI Method:**
```bash
docker exec moltbot moltbot status
```

---

## 📚 Documentation

- **README.md** - Main documentation
- **FINAL_SUMMARY.md** - Complete implementation overview
- **BUILD_OPTIMIZATION.md** - Build performance guide
- **onboarding-ui/README.md** - Web UI technical documentation
- **SECURITY.md** - Security guidelines

---

## 🎉 You're All Set!

Your Moltbot container is now running with:

✅ Auto-generated authentication token  
✅ API key validation  
✅ Better error messages  
✅ Configuration auto-healing  
✅ Web-based onboarding UI  
✅ Helper scripts for easy management  
✅ Comprehensive documentation

**Access your services:**
- Onboarding: `http://localhost:18790`
- Gateway: `http://localhost:18789`

**Happy botting! 🦞**
