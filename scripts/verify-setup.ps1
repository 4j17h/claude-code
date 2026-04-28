$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Status = 0

function Write-Ok {
  param([string]$Message)
  Write-Host "ok: $Message" -ForegroundColor Green
}

function Write-Fail {
  param([string]$Message)
  Write-Host "fail: $Message" -ForegroundColor Red
  $script:Status = 1
}

function Write-WarnLine {
  param([string]$Message)
  Write-Warning $Message
}

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Find-ClaudeCandidate {
  foreach ($candidate in @(
    (Join-Path $HOME '.local\bin\claude.exe'),
    (Join-Path $HOME '.local\bin\claude.cmd'),
    (Join-Path $HOME '.local\bin\claude')
  )) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  return $null
}

function Check-File {
  param([string]$Path)
  if (Test-Path $Path) {
    $resolved = (Resolve-Path $Path).Path
    $prefix = "$RepoRoot\"
    Write-Ok ($resolved.Replace($prefix, ''))
  } else {
    Write-Fail "missing $Path"
  }
}

Check-File (Join-Path $RepoRoot '.claude\settings.json')
Check-File (Join-Path $RepoRoot '.claude\settings.local.json')
Check-File (Join-Path $RepoRoot 'CLAUDE.md')
Check-File (Join-Path $RepoRoot 'CLAUDE.local.md')
Check-File (Join-Path $RepoRoot '.env')
Check-File (Join-Path $RepoRoot '.mcp.json')
Check-File (Join-Path $RepoRoot 'scripts\setup-macos.sh')
Check-File (Join-Path $RepoRoot 'scripts\setup-windows.ps1')
Check-File (Join-Path $RepoRoot 'scripts\start-usage-dashboard.sh')
Check-File (Join-Path $RepoRoot 'scripts\start-usage-dashboard.ps1')
Check-File (Join-Path $RepoRoot 'scripts\claude-api-mode.sh')
Check-File (Join-Path $RepoRoot 'scripts\claude-api-mode.ps1')
Check-File (Join-Path $RepoRoot 'scripts\claude-batch-mode.sh')
Check-File (Join-Path $RepoRoot 'scripts\claude-batch-mode.ps1')
Check-File (Join-Path $RepoRoot 'scripts\claude-budget-mode.sh')
Check-File (Join-Path $RepoRoot 'scripts\claude-budget-mode.ps1')
Check-File (Join-Path $RepoRoot 'scripts\verify-setup.sh')
Check-File (Join-Path $RepoRoot 'scripts\verify-setup.ps1')

$pythonCommand = if (Test-Command py) { 'py' } elseif (Test-Command python) { 'python' } else { $null }
if ($pythonCommand) {
  $jsonScript = @"
import json
from pathlib import Path
root = Path(r'$RepoRoot')
for rel in ['.claude/settings.json', '.claude/settings.local.json', '.mcp.json']:
    json.loads((root / rel).read_text())
"@
  try {
    if ($pythonCommand -eq 'py') {
      $jsonScript | py -3 -
    } else {
      $jsonScript | python -
    }
    Write-Ok 'JSON files parse successfully'
  } catch {
    Write-Fail 'JSON parsing failed'
  }
} else {
  Write-WarnLine 'Python is missing; skipped JSON parsing.'
}

if (Test-Command claude) {
  Write-Ok (claude --version)
  try {
    Write-Ok (claude auth status --text 2>&1)
  } catch {
    Write-WarnLine 'claude auth status indicates you are not logged in yet.'
  }
} else {
  $claudeCandidate = Find-ClaudeCandidate
  if ($claudeCandidate) {
    Write-Fail "claude exists at $claudeCandidate but PATH has not refreshed yet. Open a new PowerShell window and rerun verification."
  } else {
    Write-Fail 'claude command is not on PATH'
  }
}

if (Test-Command git) {
  Write-Ok (git --version)
} else {
  Write-Fail 'git command is not on PATH'
}

if (Test-Command uv) {
  Write-Ok (uv --version)
} else {
  Write-WarnLine 'uv is not installed yet (needed only for optional Python extras).'
}

if ($pythonCommand) {
  if ($pythonCommand -eq 'py') {
    Write-Ok ((py -3 --version) 2>&1)
  } else {
    Write-Ok (python --version)
  }
} else {
  Write-WarnLine 'Python is not installed yet (needed for claude-usage).'
}

if (Test-Path (Join-Path $RepoRoot '.tools\claude-usage\.git')) {
  Write-Ok 'claude-usage checkout is present'
} else {
  Write-WarnLine 'claude-usage checkout is missing; run scripts\start-usage-dashboard.ps1 or the setup script.'
}

foreach ($optionalCmd in @('rtk', 'cozempic', 'code-review-graph', 'agent-browser')) {
  if (Test-Command $optionalCmd) {
    Write-Ok "optional tool available: $optionalCmd"
  }
}

Write-Host ''
Write-Host 'Manual in-session checks to run next:'
Write-Host '  /status'
Write-Host '  /memory'
Write-Host '  /context'
Write-Host '  /usage'

exit $Status
