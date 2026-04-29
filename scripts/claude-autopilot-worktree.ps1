$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw 'claude is not installed or not on PATH.'
}

function Write-FlagWarnings {
  param(
    [string[]]$Arguments,
    [string]$PermissionMode,
    [string]$WorktreeName
  )

  $warnedPermission = $false
  $warnedDanger = $false
  $warnedWorktree = $false
  $warnedTmux = $false

  foreach ($arg in $Arguments) {
    if (-not $warnedPermission -and $arg -match '^--permission-mode($|=)') {
      Write-Warning "claude-autopilot-worktree.ps1 already sets --permission-mode $PermissionMode; avoid overriding it from the command line."
      $warnedPermission = $true
    }

    if (-not $warnedDanger -and $arg -in @('--allow-dangerously-skip-permissions', '--dangerously-skip-permissions')) {
      Write-Warning 'Do not combine autopilot worktree mode with --allow-dangerously-skip-permissions or --dangerously-skip-permissions outside isolated sandboxes.'
      $warnedDanger = $true
    }

    if (-not $warnedWorktree -and ($arg -eq '--worktree' -or $arg -eq '-w' -or $arg -match '^--worktree=')) {
      Write-Warning "claude-autopilot-worktree.ps1 already provisions --worktree $WorktreeName; avoid overriding it from the command line."
      $warnedWorktree = $true
    }

    if (-not $warnedTmux -and ($arg -eq '--tmux' -or $arg -match '^--tmux=')) {
      Write-Warning 'claude-autopilot-worktree.ps1 already manages tmux behavior via CLAUDE_AUTOPILOT_WORKTREE_TMUX; avoid overriding it from the command line.'
      $warnedTmux = $true
    }
  }
}

$permissionMode = if ($env:CLAUDE_AUTOPILOT_PERMISSION_MODE) { $env:CLAUDE_AUTOPILOT_PERMISSION_MODE } else { 'acceptEdits' }
$worktreeName = if ($env:CLAUDE_AUTOPILOT_WORKTREE_NAME) { $env:CLAUDE_AUTOPILOT_WORKTREE_NAME } else { 'autopilot-' + (Get-Date -Format 'yyyyMMddHHmmss') }
$tmuxMode = if ($env:CLAUDE_AUTOPILOT_WORKTREE_TMUX) { $env:CLAUDE_AUTOPILOT_WORKTREE_TMUX } else { '0' }
$autopilotPrompt = @(
  'Autopilot-worktree is an experimental bounded execution mode.',
  'Claude is running in an isolated git worktree created for this session.',
  'Keep changes scoped, validate after each meaningful step, and stop when complete or genuinely blocked.',
  'Worktree isolation is for containment and reviewability, not a reason to bypass permission safety, secret handling rules, or destructive-action guardrails.',
  'At the end, clearly summarize what should be merged, cherry-picked, or discarded.'
) -join ' '

Write-Warning "claude-autopilot-worktree.ps1 is experimental and defaults to --permission-mode $permissionMode in worktree $worktreeName."
if ($permissionMode -eq 'bypassPermissions') {
  Write-Warning 'bypassPermissions is not part of the supported baseline; use it only in isolated sandboxes with no internet access.'
}

Write-FlagWarnings -Arguments $args -PermissionMode $permissionMode -WorktreeName $worktreeName

$claudeArgs = @(
  '--permission-mode', $permissionMode,
  '--worktree', $worktreeName,
  '--append-system-prompt', $autopilotPrompt
)

switch -Regex ($tmuxMode) {
  '^(0|false)$' { }
  '^(1|true)$' { $claudeArgs += '--tmux' }
  default { $claudeArgs += "--tmux=$tmuxMode" }
}

$claudeArgs += $args

& claude @claudeArgs