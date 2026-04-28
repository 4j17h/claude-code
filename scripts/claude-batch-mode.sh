#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  printf 'error: claude is not installed or not on PATH\n' >&2
  exit 1
fi

exec claude -p --exclude-dynamic-system-prompt-sections "$@"
