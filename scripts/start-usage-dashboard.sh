#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TOOL_DIR="$REPO_ROOT/.tools/claude-usage"

if ! command -v git >/dev/null 2>&1; then
  printf 'error: git is required to fetch claude-usage\n' >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'error: python3 is required to run claude-usage\n' >&2
  exit 1
fi

mkdir -p "$REPO_ROOT/.tools"

if [[ ! -d "$TOOL_DIR/.git" ]]; then
  git clone https://github.com/phuryn/claude-usage "$TOOL_DIR"
fi

cd "$TOOL_DIR"
exec python3 cli.py dashboard "$@"
