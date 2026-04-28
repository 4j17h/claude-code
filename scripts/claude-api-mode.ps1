$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$EnvFile = if ($env:CLAUDE_BOOTSTRAP_ENV_FILE) { $env:CLAUDE_BOOTSTRAP_ENV_FILE } else { Join-Path $RepoRoot '.env' }

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw 'claude is not installed or not on PATH.'
}

if (-not (Test-Path $EnvFile)) {
  throw "Missing env file: $EnvFile"
}

Get-Content $EnvFile |
  Where-Object { $_ -match '=' -and -not $_.TrimStart().StartsWith('#') } |
  ForEach-Object {
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
      $name = $parts[0].Trim()
      $value = $parts[1]
      Set-Item -Path "Env:$name" -Value $value
    }
  }

if (-not $env:ANTHROPIC_API_KEY -and -not $env:CLAUDE_CODE_OAUTH_TOKEN) {
  Write-Warning "$EnvFile does not define ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN"
}

& claude @args
