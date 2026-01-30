# Unraid Management Scripts

## Container Control

### unraid-container-control.sh

Provides programmatic control of Docker containers via Unraid's GraphQL API.

**Setup:**
```bash
# Set your API key (generate in Unraid Settings → API Keys)
export UNRAID_API_KEY=your_api_key_here
export UNRAID_HOST=192.168.2.96  # optional, defaults to 192.168.2.96

# Make script executable
chmod +x ./scripts/unraid-container-control.sh
```

**Usage:**
```bash
# List all containers
./scripts/unraid-container-control.sh list

# Start a container
./scripts/unraid-container-control.sh start Plex-Media-Server

# Stop a container
./scripts/unraid-container-control.sh stop Plex-Media-Server

# Restart a container  
./scripts/unraid-container-control.sh restart Plex-Media-Server

# Check container status
./scripts/unraid-container-control.sh status Plex-Media-Server
```

**Features:**
- ✅ GraphQL API integration with secure API key authentication
- ✅ Container state management (start/stop/restart)
- ✅ Error handling and user-friendly output
- ✅ Container discovery and status reporting
- ✅ **NO HARDCODED CREDENTIALS** - uses environment variables

**Security:**
- API keys are never committed to the repository
- All authentication via environment variables
- Secure GraphQL API communication

## Requirements

- `curl` and `jq` (already available in container)
- Valid Unraid API key with Docker permissions
- Network access to Unraid server

## Troubleshooting

**"UNRAID_API_KEY environment variable not set"**
- Generate an API key in Unraid: Settings → API Keys → Add API Key
- Export it: `export UNRAID_API_KEY=your_key_here`

**"Invalid CSRF token"**  
- API key may be invalid or expired
- Regenerate the API key in Unraid settings

**Container start fails**
- Check container configuration in Unraid web UI
- Common issue: invalid tmpfs mount syntax (use `4G` not `4gb`)