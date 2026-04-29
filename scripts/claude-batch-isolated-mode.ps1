$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw 'claude is not installed or not on PATH.'
}

& claude -p --strict-mcp-config --mcp-config '{"mcpServers":{}}' --disable-slash-commands --exclude-dynamic-system-prompt-sections --permission-mode dontAsk @args