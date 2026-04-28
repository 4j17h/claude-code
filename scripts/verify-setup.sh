#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
STATUS=0
REPO_ONLY=0

ok() {
  printf 'ok: %s\n' "$*"
}

warn() {
  printf 'warn: %s\n' "$*" >&2
}

fail() {
  printf 'fail: %s\n' "$*" >&2
  STATUS=1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

while (($#)); do
  case "$1" in
    --repo-only)
      REPO_ONLY=1
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

find_local_claude() {
  local candidate
  for candidate in "$HOME/.local/bin/claude"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    ok "found ${path#$REPO_ROOT/}"
  else
    fail "missing ${path#$REPO_ROOT/}"
  fi
}

check_local_bootstrap_file() {
  local path="$1"
  local setup_hint="$2"

  if [[ -f "$path" ]]; then
    ok "found ${path#$REPO_ROOT/}"
  else
    fail "missing ${path#$REPO_ROOT/}; run ${setup_hint} to create local bootstrap files"
  fi
}

check_file "$REPO_ROOT/.claude/settings.json"
check_file "$REPO_ROOT/.env.template"
check_file "$REPO_ROOT/CLAUDE.md"
check_file "$REPO_ROOT/.mcp.json"
check_file "$REPO_ROOT/docs/support-matrix.md"
check_file "$REPO_ROOT/scripts/setup-macos.sh"
check_file "$REPO_ROOT/scripts/setup-windows.ps1"
check_file "$REPO_ROOT/scripts/start-usage-dashboard.sh"
check_file "$REPO_ROOT/scripts/start-usage-dashboard.ps1"
check_file "$REPO_ROOT/scripts/claude-api-mode.sh"
check_file "$REPO_ROOT/scripts/claude-api-mode.ps1"
check_file "$REPO_ROOT/scripts/claude-batch-mode.sh"
check_file "$REPO_ROOT/scripts/claude-batch-mode.ps1"
check_file "$REPO_ROOT/scripts/claude-budget-mode.sh"
check_file "$REPO_ROOT/scripts/claude-budget-mode.ps1"
check_file "$REPO_ROOT/scripts/verify-setup.sh"
check_file "$REPO_ROOT/scripts/verify-setup.ps1"

if have python3; then
  if REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import json
import os
from pathlib import Path
root = Path(os.environ["REPO_ROOT"])
for rel in [".claude/settings.json", ".mcp.json"]:
    json.loads((root / rel).read_text())

local_settings = root / ".claude/settings.local.json"
if local_settings.exists():
    json.loads(local_settings.read_text())
PY
  then
    ok 'JSON files parse successfully'
  else
    fail 'JSON parsing failed'
  fi
else
  warn 'python3 not found; skipped JSON parsing'
fi

if [[ "$REPO_ONLY" == "0" ]]; then
  check_local_bootstrap_file "$REPO_ROOT/.claude/settings.local.json" 'scripts/setup-macos.sh or scripts/setup-windows.ps1'
  check_local_bootstrap_file "$REPO_ROOT/CLAUDE.local.md" 'scripts/setup-macos.sh or scripts/setup-windows.ps1'
  check_local_bootstrap_file "$REPO_ROOT/.env" 'scripts/setup-macos.sh or scripts/setup-windows.ps1'

  if have claude; then
    ok "$(claude --version)"
    if output="$(claude auth status --text 2>&1)"; then
      ok "$output"
    else
      warn "$output"
    fi
  else
    if claude_candidate="$(find_local_claude)"; then
      fail "claude exists at $claude_candidate but PATH has not refreshed yet; open a new shell or source your shell profile and rerun verify"
    else
      fail 'claude command is not on PATH'
    fi
  fi

  if have uv; then
    ok "$(uv --version)"
  else
    warn 'uv is not installed yet (needed only for optional Python extras)'
  fi

  if have git; then
    ok "$(git --version)"
  else
    fail 'git command is not on PATH'
  fi

  if have python3; then
    ok "$(python3 --version)"
  else
    warn 'python3 is not installed yet (needed for claude-usage)'
  fi

  if [[ -d "$REPO_ROOT/.tools/claude-usage/.git" ]]; then
    ok 'claude-usage checkout is present'
  else
    warn 'claude-usage checkout is missing; run scripts/start-usage-dashboard.sh or setup script'
  fi

  for optional_cmd in rtk cozempic code-review-graph agent-browser; do
    if have "$optional_cmd"; then
      ok "optional tool available: $optional_cmd"
    fi
  done

  printf '\nManual in-session checks to run next:\n'
  printf '  /status\n'
  printf '  /memory\n'
  printf '  /context\n'
  printf '  /usage\n'
  printf '\nSupport tiers:\n'
  printf '  baseline: Claude Code, shared repo settings, setup/verify/mode scripts\n'
  printf '  local bootstrap: .env, CLAUDE.local.md, .claude/settings.local.json\n'
  printf '  optional tools: rtk, cozempic, code-review-graph, agent-browser, claude-usage\n'
else
  ok 'repo-only mode skips local bootstrap and machine checks'
  printf '\nRepo-only mode validated the committed baseline.\n'
fi

exit "$STATUS"
