#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
Usage: bash scripts/claude-batch-commit-mode.sh [additional context]

Generate a git commit message from the staged diff using a stripped-down Claude invocation.
Set CLAUDE_COMMIT_MODEL to override the default model (haiku).
EOF
}

if (($#)) && [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  printf 'error: claude is not installed or not on PATH\n' >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  printf 'error: git is not installed or not on PATH\n' >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'error: claude-batch-commit-mode.sh must be run inside a git repository\n' >&2
  exit 1
fi

if git diff --cached --quiet --exit-code; then
  printf 'error: no staged changes found; stage changes with git add before using claude-batch-commit-mode.sh\n' >&2
  exit 1
fi

model="${CLAUDE_COMMIT_MODEL:-haiku}"
staged_diff="$(git diff --cached --no-ext-diff)"
additional_context="${*:-}"
prompt=$'Write a git commit message for the staged changes below.\n\nRequirements:\n- Output only the commit message.\n- Subject line under 50 characters.\n- Use imperative mood.\n- Add a body only when it materially helps explain the change.\n- Follow conventional commits only if the repository already uses them or the diff clearly suggests it.\n'

if [[ -n "$additional_context" ]]; then
  prompt+=$'\nAdditional context:\n'"$additional_context"$'\n'
fi

prompt+=$'\n<diff>\n'"$staged_diff"$'\n</diff>\n'
overlay='You are generating a git commit message from a staged diff. Return only the commit message text with no fences, quotes, or surrounding commentary.'

printf '%s' "$prompt" | claude -p \
  --no-session-persistence \
  --model "$model" \
  --tools "" \
  --disable-slash-commands \
  --setting-sources "" \
  --exclude-dynamic-system-prompt-sections \
  --append-system-prompt "$overlay"