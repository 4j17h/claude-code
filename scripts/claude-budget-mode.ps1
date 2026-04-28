$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw 'claude is not installed or not on PATH.'
}

if (-not $env:CLAUDE_CODE_EFFORT_LEVEL) { $env:CLAUDE_CODE_EFFORT_LEVEL = 'low' }
if (-not $env:CLAUDE_CODE_DISABLE_THINKING) { $env:CLAUDE_CODE_DISABLE_THINKING = '1' }
if (-not $env:CLAUDE_CODE_DISABLE_AUTO_MEMORY) { $env:CLAUDE_CODE_DISABLE_AUTO_MEMORY = '1' }
if (-not $env:CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION) { $env:CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION = 'false' }
if (-not $env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE) { $env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = '70' }

& claude @args
