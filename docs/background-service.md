# Background Service

Run dev's OpenAI-compatible server in the background using Homebrew services. Same pattern as Ollama, PostgreSQL, nginx.

## Quick Start

```bash
brew services start dev
```

The server starts at `http://127.0.0.1:11434` and auto-restarts on crash or login.

## Commands

```bash
brew services start dev          # Start (auto-starts at login)
brew services stop dev           # Stop
brew services restart dev        # Restart
brew services info dev           # Status
brew services list                 # All services
```

## Logs

```bash
tail -f /opt/homebrew/var/log/dev.log
```

## Configuration via Environment

dev reads configuration from environment variables. Set them before starting the service:

```bash
# Custom port
DEV_PORT=8080 brew services start dev

# Token authentication
DEV_TOKEN="my-secret" brew services start dev
DEV_TOKEN=$(uuidgen) brew services start dev

# Attach MCP tool servers (colon-separated paths)
DEV_MCP="/path/to/server.py" brew services start dev
DEV_MCP="/path/a.py:/path/b.py" brew services start dev

# MCP timeout for slow/remote servers (default: 5s, max: 300s)
DEV_MCP_TIMEOUT=30 DEV_MCP="/path/to/remote-server.py" brew services start dev

# System prompt
DEV_SYSTEM_PROMPT="Be concise" brew services start dev

# Custom host (expose to network - see security note below)
DEV_HOST=0.0.0.0 DEV_TOKEN=$(uuidgen) brew services start dev
```

All `DEV_*` variables: see `dev --help` under ENVIRONMENT.

## Security

The background service uses the same security model as `dev --serve`:

- **Default: localhost only.** Binds to `127.0.0.1` unless `DEV_HOST` overrides.
- **Token auth.** Set `DEV_TOKEN` for Bearer authentication.
- **When exposing to network** (`DEV_HOST=0.0.0.0`), always set a token:
  ```bash
  DEV_HOST=0.0.0.0 DEV_TOKEN=$(uuidgen) brew services start dev
  ```

See [Server Security](server-security.md) for full details.

## Manual Plist (Advanced)

For configurations that Homebrew's service doesn't cover (custom flags, complex MCP setups), create a plist manually:

```bash
cat > ~/Library/LaunchAgents/com.innovatorved.sayitdev.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.innovatorved.sayitdev</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/opt/dev/bin/dev</string>
        <string>--serve</string>
        <string>--port</string>
        <string>11434</string>
        <string>--mcp</string>
        <string>/absolute/path/to/server.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/dev.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/dev.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>/Users/YOUR_USERNAME</string>
        <key>DEV_TOKEN</key>
        <string>YOUR_TOKEN</string>
    </dict>
</dict>
</plist>
EOF

# Load
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.innovatorved.sayitdev.plist

# Unload
launchctl bootout gui/$(id -u)/com.innovatorved.sayitdev

# Check status
launchctl print gui/$(id -u)/com.innovatorved.sayitdev
```

Use `/opt/homebrew/opt/dev/bin/dev` (not the Cellar path) so it survives `brew upgrade`.
