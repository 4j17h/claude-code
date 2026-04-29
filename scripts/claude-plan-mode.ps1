$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw 'claude is not installed or not on PATH.'
}

function Write-FlagWarnings {
  param([string[]]$Arguments)

  $warnedPermission = $false
  $warnedDanger = $false

  foreach ($arg in $Arguments) {
    if (-not $warnedPermission -and $arg -match '^--permission-mode($|=)') {
      Write-Warning 'claude-plan-mode.ps1 already sets --permission-mode plan; avoid overriding it from the command line.'
      $warnedPermission = $true
    }

    if (-not $warnedDanger -and $arg -in @('--allow-dangerously-skip-permissions', '--dangerously-skip-permissions')) {
      Write-Warning 'Do not combine planning mode with --allow-dangerously-skip-permissions or --dangerously-skip-permissions outside isolated sandboxes.'
      $warnedDanger = $true
    }
  }
}

$planPrompt = @(
  'Stay in planning mode.',
  'Clarify unclear requirements before implementation.',
  'Produce a concrete plan with assumptions, risks, validation steps, and rollback notes when relevant.',
  'Do not make code changes unless the user explicitly asks to move from planning into execution.'
) -join ' '

Write-FlagWarnings -Arguments $args

& claude --permission-mode plan --append-system-prompt $planPrompt @args