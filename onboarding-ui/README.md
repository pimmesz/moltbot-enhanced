# Moltbot Onboarding Web UI

A web-based interface for interacting with Moltbot's CLI onboarding wizard, making it easy to set up Moltbot without needing terminal access.

## 🎯 Features

- **Web-based Terminal** - Interactive terminal in your browser
- **No SSH Required** - Perfect for Unraid users
- **Multiple Commands** - Access onboard, configure, doctor, and more
- **Real-time Communication** - WebSocket-based PTY for instant feedback
- **Command History** - Navigate previous commands with arrow keys
- **ANSI Color Support** - Full terminal color support

## 🚀 How It Works

### Architecture

```
Browser (Vue.js)
    ↕ WebSocket
Node.js Server (Express + WS)
    ↕ PTY (node-pty)
Moltbot CLI (moltbot onboard, configure, etc.)
```

1. **Frontend (Vue.js)**: Provides the web interface with a terminal-like display
2. **Backend (Node.js)**: Manages WebSocket connections and spawns PTY processes
3. **PTY (node-pty)**: Creates pseudo-terminals to run interactive CLI commands
4. **Moltbot CLI**: The actual moltbot commands being executed

## 📦 Components

### Backend (`server/index.js`)
- Express server on port 18790
- WebSocket server for real-time communication
- PTY process management using `node-pty`
- Session management for multiple concurrent users
- API endpoints for health and command list

### Frontend (`src/App.vue`)
- Vue 3 Composition API
- Terminal output display with ANSI color support
- Input handling with command history
- WebSocket client for real-time communication
- Command selector interface

## 🔧 Usage

### Accessing the UI

Once the Docker container is running:

```bash
# Open in your browser
http://localhost:18790

# Or on Unraid
http://YOUR-UNRAID-IP:18790
```

### Available Commands

- **Full Onboarding** - `moltbot onboard` - Complete setup wizard
- **Configure** - `moltbot configure` - Update credentials and settings
- **Health Check** - `moltbot doctor` - Run diagnostics and fixes
- **Add Channels** - `moltbot channels login` - Connect messaging platforms
- **Status** - `moltbot status` - View current status

### Using the Terminal

1. Click on a command to start
2. Type your responses in the input field
3. Press Enter to send
4. Use ↑/↓ arrow keys to navigate command history
5. Click 🗑️ to clear output
6. Click ⏹️ to stop the current session

## 🎨 Terminal Features

### Input Handling
- **Enter**: Send input to the terminal
- **↑ Arrow**: Previous command in history
- **↓ Arrow**: Next command in history
- Auto-focus on terminal start

### Output Handling
- Real-time streaming output
- ANSI color code support
- Auto-scroll to bottom
- Clear terminal function
- Session end detection

### Session Management
- Each command runs in its own PTY session
- Sessions are cleaned up on disconnect
- Exit codes are displayed
- Restart capability

## 🔒 Security Considerations

### Current Implementation
- No authentication (container is isolated)
- WebSocket on same host as gateway
- Commands run as the container user (PUID/PGID)
- Sessions are per-connection

### For Production
Consider adding:
- Token-based authentication
- Rate limiting
- Command whitelisting
- Audit logging
- TLS/SSL support

## 🐛 Troubleshooting

### UI not loading
```bash
# Check if onboarding service is running
docker exec moltbot ps aux | grep node

# Check logs
docker exec moltbot cat /tmp/onboarding-ui.log
```

### WebSocket connection fails
```bash
# Check if port 18790 is exposed
docker port moltbot

# Verify firewall rules on Unraid
# Check Network tab in container settings
```

### Terminal not responding
- Refresh the page
- Stop and restart the session
- Check Docker logs: `docker logs moltbot`

### ANSI codes not rendering
- This is normal for some output
- The UI converts common ANSI codes to HTML
- Complex terminal features may not work

## 🔄 Development

### Local Development

```bash
cd onboarding-ui

# Install dependencies
npm install

# Run dev server (with hot reload)
npm run dev

# Build for production
npm run build
```

### Testing Changes

```bash
# Rebuild Docker image
docker-compose build

# Restart container
docker-compose up -d

# View logs
docker-compose logs -f
```

## 📝 API Reference

### WebSocket Messages

#### Client → Server

```javascript
// Start a command
{
  "type": "start",
  "command": "moltbot",
  "args": ["onboard"]
}

// Send input
{
  "type": "input",
  "data": "yes\n"
}

// Resize terminal
{
  "type": "resize",
  "cols": 120,
  "rows": 30
}

// Kill session
{
  "type": "kill"
}
```

#### Server → Client

```javascript
// Session started
{
  "type": "started",
  "sessionId": "abc123"
}

// Terminal output
{
  "type": "output",
  "data": "Welcome to moltbot...\n"
}

// Session exited
{
  "type": "exit",
  "exitCode": 0,
  "signal": null
}

// Error
{
  "type": "error",
  "message": "No active session"
}
```

### HTTP Endpoints

#### GET `/api/health`
```json
{
  "status": "ok",
  "sessions": 2,
  "uptime": 1234.56
}
```

#### GET `/api/commands`
```json
{
  "commands": [
    {
      "id": "onboard",
      "name": "Full Onboarding",
      "command": "moltbot",
      "args": ["onboard"]
    }
  ]
}
```

## 🎓 Technical Details

### Why node-pty?
- Provides a real pseudo-terminal (PTY)
- Supports interactive CLI tools
- Handles terminal control codes
- Works with stdin/stdout/stderr properly
- Better than simple `child_process.spawn()`

### Why WebSocket?
- Real-time bidirectional communication
- Lower latency than HTTP polling
- Efficient for streaming data
- Native browser support

### Why Vue.js?
- Reactive UI updates
- Component-based architecture
- Small bundle size
- Easy to maintain

## 📚 Resources

- [node-pty Documentation](https://github.com/microsoft/node-pty)
- [WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [Vue.js Documentation](https://vuejs.org/)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)

## 🤝 Contributing

Improvements welcome! Areas for enhancement:
- Better ANSI code support
- Multiple concurrent sessions per user
- File upload/download
- Command templates
- Dark/light theme toggle
- Keyboard shortcuts
- Session recording/playback
