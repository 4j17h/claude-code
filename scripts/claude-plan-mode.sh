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
          printf 'warning: claude-plan-mode.sh already sets --permission-mode plan; avoid overriding it from the command line\n' >&2
          warned_permission=1
        fi
        ;;
      --allow-dangerously-skip-permissions|--dangerously-skip-permissions)
        if [[ "$warned_danger" == "0" ]]; then
          printf 'warning: do not combine planning mode with --allow-dangerously-skip-permissions or --dangerously-skip-permissions outside isolated sandboxes\n' >&2
          warned_danger=1
        fi
        ;;
    esac
  done
}

plan_prompt=$(cat <<'EOF'
Stay in planning mode. Clarify unclear requirements before implementation. Produce a concrete plan with assumptions, risks, validation steps, and rollback notes when relevant. Do not make code changes unless the user explicitly asks to move from planning into execution.
EOF
)

warn_if_conflicting_flags "$@"

exec claude --permission-mode plan --append-system-prompt "$plan_prompt" "$@"