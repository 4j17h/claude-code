param(
  [switch]$EnableApiMode = ($env:ENABLE_API_MODE -eq '1'),
  [switch]$EnableRtk = ($env:ENABLE_RTK -eq '1'),
  [switch]$EnableCozempic = ($env:ENABLE_COZEMPIC -eq '1'),
  [switch]$EnableCodeReviewGraph = ($env:ENABLE_CODE_REVIEW_GRAPH -eq '1'),
  [switch]$EnableAgentBrowser = ($env:ENABLE_AGENT_BROWSER -eq '1'),
  [switch]$SkipClaudeUsage = ($env:INSTALL_CLAUDE_USAGE -eq '0')
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ClaudeChannel = if ($env:CLAUDE_CHANNEL) { $env:CLAUDE_CHANNEL } else { 'stable' }

function Write-Step {
  param([string]$Message)
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-PathEntryPresent {
  param(
    [string]$PathValue,
    [string]$PathEntry
  )

  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return $false
  }

  $normalizedTarget = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($PathEntry)).TrimEnd('\')
  foreach ($entry in ($PathValue -split ';')) {
    if ([string]::IsNullOrWhiteSpace($entry)) {
      continue
    }

    $expandedEntry = [Environment]::ExpandEnvironmentVariables($entry).Trim()
    try {
      $normalizedEntry = [System.IO.Path]::GetFullPath($expandedEntry).TrimEnd('\')
    } catch {
      $normalizedEntry = $expandedEntry.TrimEnd('\')
    }

    if ($normalizedEntry.Equals($normalizedTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function Add-ToPathIfExists {
  param([string]$PathEntry)
  if ((Test-Path $PathEntry) -and -not (Test-PathEntryPresent $env:Path $PathEntry)) {
    $env:Path = "$PathEntry;$env:Path"
  }
}

function Ensure-UserPathEntry {
  param([string]$PathEntry)

  if (-not (Test-Path $PathEntry)) {
    return $false
  }

  Add-ToPathIfExists $PathEntry

  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not (Test-PathEntryPresent $userPath $PathEntry)) {
    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
      $PathEntry
    } else {
      "$PathEntry;$userPath"
    }

    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    Write-Step "Added $PathEntry to the user PATH"
  }

  return $true
}

function Ensure-Git {
  if (Test-Command git) { return }

  if (Test-Command winget) {
    Write-Step 'Installing Git for Windows'
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements | Out-Null
    Add-ToPathIfExists (Join-Path $env:ProgramFiles 'Git\cmd')
    return
  }

  Write-Warning 'Git for Windows is required for native Claude Code on Windows. Install it and rerun setup.'
}

function Ensure-Claude {
  if (-not (Test-Command claude)) {
    Write-Step 'Installing Claude Code with the native Windows installer'
    irm https://claude.ai/install.ps1 | iex
  }

  Ensure-UserPathEntry (Join-Path $HOME '.local\bin') | Out-Null

  if (-not (Test-Command claude)) {
    throw 'Claude Code was not found after installation.'
  }

  Write-Step "Ensuring Claude Code follows the $ClaudeChannel channel"
  try {
    claude install $ClaudeChannel | Out-Null
  } catch {
    Write-Warning "claude install $ClaudeChannel failed; keeping the current install"
  }
}

function Ensure-Uv {
  if (Test-Command uv) { return }

  Write-Step 'Installing uv'
  irm https://astral.sh/uv/install.ps1 | iex
  Ensure-UserPathEntry (Join-Path $HOME '.local\bin') | Out-Null

  if (-not (Test-Command uv)) {
    Write-Warning 'uv is not on PATH yet. Restart your shell if later tool installs fail.'
  }
}

function Ensure-LocalFiles {
  $claudeDir = Join-Path $RepoRoot '.claude'
  if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir | Out-Null
  }

  $envFile = Join-Path $RepoRoot '.env'
  if (-not (Test-Path $envFile)) {
    Write-Step 'Creating local .env from .env.template'
    Copy-Item -Path (Join-Path $RepoRoot '.env.template') -Destination $envFile
  }

  $localSettings = Join-Path $claudeDir 'settings.local.json'
  if (-not (Test-Path $localSettings)) {
    Write-Step 'Creating .claude/settings.local.json'
    @'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {}
}
'@ | Set-Content -Path $localSettings -Encoding utf8
  }

  $localClaude = Join-Path $RepoRoot 'CLAUDE.local.md'
  if (-not (Test-Path $localClaude)) {
    Write-Step 'Creating CLAUDE.local.md'
    @'
# Local notes

- Add personal workflow notes here.
- Keep machine-specific paths, proxies, and experiments in this file.
- Do not commit this file.
'@ | Set-Content -Path $localClaude -Encoding utf8
  }
}

function Install-ClaudeUsage {
  if ($SkipClaudeUsage) { return }

  Ensure-Git

  $pythonCommand = if (Test-Command py) { 'py' } elseif (Test-Command python) { 'python' } else { $null }
  if (-not $pythonCommand) {
    Write-Warning 'Python is missing. claude-usage will be skipped until Python is installed.'
    return
  }

  $toolsDir = Join-Path $RepoRoot '.tools'
  $checkout = Join-Path $toolsDir 'claude-usage'
  if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
  }

  if (-not (Test-Path (Join-Path $checkout '.git'))) {
    Write-Step 'Cloning claude-usage'
    git clone https://github.com/phuryn/claude-usage $checkout | Out-Null
  } else {
    Write-Step 'Updating claude-usage'
    git -C $checkout pull --ff-only | Out-Null
  }
}

function Install-Rtk {
  if (-not $EnableRtk) { return }

  if (-not (Test-Command rtk)) {
    Write-Step 'Installing RTK for native Windows'
    $localBin = Join-Path $HOME '.local\bin'
    if (-not (Test-Path $localBin)) {
      New-Item -ItemType Directory -Path $localBin | Out-Null
    }

    $zipPath = Join-Path $env:TEMP 'rtk-x86_64-pc-windows-msvc.zip'
    Invoke-WebRequest -Uri 'https://github.com/rtk-ai/rtk/releases/latest/download/rtk-x86_64-pc-windows-msvc.zip' -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $localBin -Force
    Ensure-UserPathEntry $localBin | Out-Null
  }

  if (Test-Command rtk) {
    Write-Step 'Initializing RTK for Claude Code (native Windows uses limited hook mode)'
    $env:RTK_TELEMETRY_DISABLED = '1'
    try {
      rtk init -g --auto-patch | Out-Null
    } catch {
      Write-Warning 'RTK init needs manual follow-up.'
    }
  } else {
    Write-Warning 'RTK could not be installed automatically.'
  }
}

function Install-Cozempic {
  if (-not $EnableCozempic) { return }

  Ensure-Uv
  if (-not (Test-Command uv)) {
    Write-Warning 'uv is required for the optional Cozempic install.'
    return
  }

  if (-not (Test-Command cozempic)) {
    Write-Step 'Installing Cozempic via uv'
    try {
      uv tool install cozempic | Out-Null
    } catch {
      Write-Warning 'Cozempic install failed.'
    }
  }

  Ensure-UserPathEntry (Join-Path $HOME '.local\bin') | Out-Null

  if (Test-Command cozempic) {
    Write-Step 'Initializing Cozempic'
    $env:COZEMPIC_NO_TELEMETRY = '1'
    try {
      cozempic init | Out-Null
    } catch {
      Write-Warning 'Cozempic init needs manual follow-up.'
    }
  }
}

function Install-CodeReviewGraph {
  if (-not $EnableCodeReviewGraph) { return }

  Ensure-Uv
  if (-not (Test-Command uv)) {
    Write-Warning 'uv is required for the optional code-review-graph install.'
    return
  }

  if (-not (Test-Command code-review-graph)) {
    Write-Step 'Installing code-review-graph via uv'
    try {
      uv tool install code-review-graph | Out-Null
    } catch {
      Write-Warning 'code-review-graph install failed.'
    }
  }

  Ensure-UserPathEntry (Join-Path $HOME '.local\bin') | Out-Null

  if (Test-Command code-review-graph) {
    Write-Step 'Configuring code-review-graph for Claude Code'
    try {
      code-review-graph install --platform claude-code | Out-Null
    } catch {
      Write-Warning 'code-review-graph install needs manual follow-up.'
    }
  }
}

function Install-AgentBrowser {
  if (-not $EnableAgentBrowser) { return }

  if (-not (Test-Command npm)) {
    Write-Warning 'Node/npm is missing. Skipping the optional agent-browser install.'
    return
  }

  Write-Step 'Installing agent-browser via npm'
  npm install -g agent-browser | Out-Null

  if (Test-Command agent-browser) {
    Write-Step 'Installing agent-browser browser runtime'
    try {
      agent-browser install | Out-Null
    } catch {
      Write-Warning 'agent-browser install needs manual follow-up.'
    }
  } else {
    Write-Warning 'agent-browser is not on PATH after npm install.'
    return
  }

  if (Test-Command npx) {
    Write-Step 'Adding the optional agent-browser Claude skill stub'
    try {
      npx skills add vercel-labs/agent-browser | Out-Null
    } catch {
      Write-Warning 'Could not add the agent-browser Claude skill.'
    }
  }
}

Ensure-Claude
Ensure-LocalFiles
Install-ClaudeUsage
Install-Rtk
Install-Cozempic
Install-CodeReviewGraph
Install-AgentBrowser

if ($EnableApiMode) {
  Write-Step 'API mode requested'
  Write-Warning "Fill in $RepoRoot\.env before using scripts\claude-api-mode.ps1"
}

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'The setup script adds %USERPROFILE%\.local\bin to the current session and user PATH so new terminals can find claude automatically.'
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Log in with your preferred auth mode:'
Write-Host '     - Subscription / Teams: claude'
Write-Host "     - Optional API mode: $RepoRoot\scripts\claude-api-mode.ps1"
Write-Host "     - Optional budget mode: $RepoRoot\scripts\claude-budget-mode.ps1"
Write-Host "     - Optional batch mode: $RepoRoot\scripts\claude-batch-mode.ps1"
Write-Host "  2. Verify the setup: $RepoRoot\scripts\verify-setup.ps1"
Write-Host '  3. Optional extras can be toggled by re-running setup with flags:'
Write-Host '     - .\scripts\setup-windows.ps1 -EnableRtk'
Write-Host '     - .\scripts\setup-windows.ps1 -EnableCodeReviewGraph'
Write-Host '     - .\scripts\setup-windows.ps1 -EnableCozempic'
Write-Host '     - .\scripts\setup-windows.ps1 -EnableAgentBrowser'
