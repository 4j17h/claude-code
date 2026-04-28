$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ToolDir = Join-Path $RepoRoot '.tools\claude-usage'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'git is required to fetch claude-usage.'
}

$pythonCommand = if (Get-Command py -ErrorAction SilentlyContinue) { 'py' } elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { $null }
if (-not $pythonCommand) {
  throw 'Python is required to run claude-usage.'
}

if (-not (Test-Path (Join-Path $RepoRoot '.tools'))) {
  New-Item -ItemType Directory -Path (Join-Path $RepoRoot '.tools') | Out-Null
}

if (-not (Test-Path (Join-Path $ToolDir '.git'))) {
  git clone https://github.com/phuryn/claude-usage $ToolDir | Out-Null
}

Push-Location $ToolDir
try {
  if ($pythonCommand -eq 'py') {
    & py -3 cli.py dashboard @args
  } else {
    & python cli.py dashboard @args
  }
} finally {
  Pop-Location
}
