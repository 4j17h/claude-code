#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${CLAUDE_BOOTSTRAP_ENV_FILE:-$REPO_ROOT/.env}"

if ! command -v claude >/dev/null 2>&1; then
  printf 'error: claude is not installed or not on PATH\n' >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  printf 'error: missing env file: %s\n' "$ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${ANTHROPIC_API_KEY:-}" && -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  printf 'warning: %s does not define ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN\n' "$ENV_FILE" >&2
fi

exec claude "$@"
