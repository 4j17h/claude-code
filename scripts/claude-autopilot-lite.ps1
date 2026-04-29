$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw 'claude is not installed or not on PATH.'
}

function Write-FlagWarnings {
  param(
    [string[]]$Arguments,
    [string]$PermissionMode
  )

  $warnedPermission = $false
  $warnedDanger = $false

  foreach ($arg in $Arguments) {
    if (-not $warnedPermission -and $arg -match '^--permission-mode($|=)') {
      Write-Warning "claude-autopilot-lite.ps1 already sets --permission-mode $PermissionMode; avoid overriding it from the command line."
      $warnedPermission = $true
    }

    if (-not $warnedDanger -and $arg -in @('--allow-dangerously-skip-permissions', '--dangerously-skip-permissions')) {
      Write-Warning 'Do not combine autopilot-lite with --allow-dangerously-skip-permissions or --dangerously-skip-permissions outside isolated sandboxes.'
      $warnedDanger = $true
    }
  }
}

$permissionMode = if ($env:CLAUDE_AUTOPILOT_PERMISSION_MODE) { $env:CLAUDE_AUTOPILOT_PERMISSION_MODE } else { 'acceptEdits' }
$autopilotPrompt = @(
  'Autopilot-lite is a bounded execution mode.',
  'Start with a brief plan, then execute in small safe steps, validate after each meaningful change, repair local failures when possible, and stop when complete or genuinely blocked.',
  'Surface assumptions, avoid destructive actions without explicit user intent, and prefer asking for clarification over inventing missing requirements.'
) -join ' '

Write-Warning "claude-autopilot-lite.ps1 is experimental and defaults to --permission-mode $permissionMode."
if ($permissionMode -eq 'bypassPermissions') {
  Write-Warning 'bypassPermissions is not part of the supported baseline; use it only in isolated sandboxes with no internet access.'
}

Write-FlagWarnings -Arguments $args -PermissionMode $permissionMode

& claude --permission-mode $permissionMode --append-system-prompt $autopilotPrompt @args