# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do NOT open a public GitHub issue**
2. Email the maintainer directly or use GitHub's private vulnerability reporting
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond within 48 hours and work with you to address the issue.

## Security Best Practices

### API Keys

- **Never commit API keys** to version control
- Use environment variables or Docker secrets
- Rotate keys periodically
- Use the minimum required permissions

### Container Security

This container follows security best practices:

1. **Non-root execution**: Runs as user specified by PUID/PGID
2. **Minimal base image**: Alpine Linux with minimal packages
3. **No Docker socket**: Does not require Docker socket access
4. **Single volume**: Only writes to `/config`

### Recommended Hardening

For production deployments, consider:

```bash
docker run \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --cap-drop ALL \
  --cap-add CHOWN \
  --cap-add SETGID \
  --cap-add SETUID \
  --security-opt no-new-privileges:true \
  ...
```

### Network Security

- The gateway binds to `lan` by default (accessible on local network)
- Use `--bind loopback` for localhost-only access
- Consider a reverse proxy (Traefik, nginx) for TLS termination
- Set `MOLTBOT_TOKEN` to require authentication

### Messaging Platform Credentials

Channel credentials (WhatsApp session, bot tokens) are stored in:
- `/config/.clawdbot/credentials/`

Ensure:
- `/config` volume has appropriate permissions (PUID/PGID)
- Backup credentials securely
- Don't share credential files

## Security Updates

- Monitor the [Moltbot releases](https://github.com/moltbot/moltbot/releases) for security updates
- Update the container regularly: `docker pull pimmesz/moltbot-unraid:latest`
- Subscribe to security advisories

## Scope

This security policy covers:
- The Docker container build and configuration
- The entrypoint script (`start.sh`)
- CI/CD pipeline

For vulnerabilities in Moltbot itself, report to the [upstream project](https://github.com/moltbot/moltbot).
