$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw 'claude is not installed or not on PATH.'
}

& claude -p --output-format stream-json --include-partial-messages --exclude-dynamic-system-prompt-sections @args