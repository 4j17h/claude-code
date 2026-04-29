param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$AdditionalContext
)

$ErrorActionPreference = 'Stop'

if ($AdditionalContext.Count -gt 0 -and ($AdditionalContext[0] -eq '--help' -or $AdditionalContext[0] -eq '-h')) {
  Write-Host @'
Usage: .\scripts\claude-batch-commit-mode.ps1 [additional context]

Generate a git commit message from the staged diff using a stripped-down Claude invocation.
Set CLAUDE_COMMIT_MODEL to override the default model (haiku).
'@
  exit 0
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw 'claude is not installed or not on PATH.'
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'git is not installed or not on PATH.'
}

$null = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0) {
  throw 'claude-batch-commit-mode.ps1 must be run inside a git repository.'
}

& git diff --cached --quiet --exit-code
if ($LASTEXITCODE -eq 0) {
  throw 'no staged changes found; stage changes with git add before using claude-batch-commit-mode.ps1.'
}

$model = if ($env:CLAUDE_COMMIT_MODEL) { $env:CLAUDE_COMMIT_MODEL } else { 'haiku' }
$stagedDiff = (git diff --cached --no-ext-diff | Out-String).TrimEnd("`r", "`n")
$contextNote = ($AdditionalContext -join ' ').Trim()
$promptLines = @(
  'Write a git commit message for the staged changes below.',
  '',
  'Requirements:',
  '- Output only the commit message.',
  '- Subject line under 50 characters.',
  '- Use imperative mood.',
  '- Add a body only when it materially helps explain the change.',
  '- Follow conventional commits only if the repository already uses them or the diff clearly suggests it.'
)

if ($contextNote) {
  $promptLines += ''
  $promptLines += 'Additional context:'
  $promptLines += $contextNote
}

$promptLines += ''
$promptLines += '<diff>'
$promptLines += $stagedDiff
$promptLines += '</diff>'

$prompt = $promptLines -join "`n"
$overlay = 'You are generating a git commit message from a staged diff. Return only the commit message text with no fences, quotes, or surrounding commentary.'

$prompt | & claude -p --no-session-persistence --model $model --tools '' --disable-slash-commands --setting-sources '' --exclude-dynamic-system-prompt-sections --append-system-prompt $overlay