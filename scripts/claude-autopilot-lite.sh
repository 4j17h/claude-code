#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  printf 'error: claude is not installed or not on PATH\n' >&2
  exit 1
fi

warn_if_conflicting_flags() {
  local warned_permission=0
  local warned_danger=0
  local arg

  for arg in "$@"; do
    case "$arg" in
      --permission-mode|--permission-mode=*)
        if [[ "$warned_permission" == "0" ]]; then
          printf 'warning: claude-autopilot-lite.sh already sets --permission-mode %s; avoid overriding it from the command line\n' "$permission_mode" >&2
          warned_permission=1
        fi
        ;;
      --allow-dangerously-skip-permissions|--dangerously-skip-permissions)
        if [[ "$warned_danger" == "0" ]]; then
          printf 'warning: do not combine autopilot-lite with --allow-dangerously-skip-permissions or --dangerously-skip-permissions outside isolated sandboxes\n' >&2
          warned_danger=1
        fi
        ;;
    esac
  done
}

permission_mode="${CLAUDE_AUTOPILOT_PERMISSION_MODE:-acceptEdits}"
autopilot_prompt=$(cat <<'EOF'
Autopilot-lite is a bounded execution mode. Start with a brief plan, then execute in small safe steps, validate after each meaningful change, repair local failures when possible, and stop when complete or genuinely blocked. Surface assumptions, avoid destructive actions without explicit user intent, and prefer asking for clarification over inventing missing requirements.
EOF
)

printf 'warning: claude-autopilot-lite.sh is experimental and defaults to --permission-mode %s\n' "$permission_mode" >&2
if [[ "$permission_mode" == "bypassPermissions" ]]; then
  printf 'warning: bypassPermissions is not part of the supported baseline; use it only in isolated sandboxes with no internet access\n' >&2
fi

warn_if_conflicting_flags "$@"

exec claude --permission-mode "$permission_mode" --append-system-prompt "$autopilot_prompt" "$@"