# Unraid Management Scripts

## Container Control

### unraid-container-control.sh

Provides programmatic control of Docker containers via Unraid's GraphQL API.

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
- ✅ GraphQL API integration with API key authentication
- ✅ Container state management (start/stop/restart)
- ✅ Error handling and user-friendly output
- ✅ Container discovery and status reporting

**API Key:** Set via environment variable:
```bash
export UNRAID_API_KEY=your_api_key_here
export UNRAID_HOST=192.168.2.96  # optional, defaults to 192.168.2.96
```

## Notes

- Requires `curl` and `jq` (already available in container)
- Uses Unraid's GraphQL endpoint at `http://192.168.2.96/graphql` 
- All container names should be provided without the leading `/` (e.g., `Plex-Media-Server` not `/Plex-Media-Server`)

## Troubleshooting

If container start fails due to configuration issues (e.g., tmpfs mount problems), the error will be displayed. Fix the container configuration in Unraid's web UI first, then retry the script.