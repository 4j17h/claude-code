#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  printf 'error: claude is not installed or not on PATH\n' >&2
  exit 1
fi

warn_if_conflicting_flags() {
  local warned_permission=0
  local warned_danger=0
  local warned_worktree=0
  local warned_tmux=0
  local arg

  for arg in "$@"; do
    case "$arg" in
      --permission-mode|--permission-mode=*)
        if [[ "$warned_permission" == "0" ]]; then
          printf 'warning: claude-autopilot-worktree.sh already sets --permission-mode %s; avoid overriding it from the command line\n' "$permission_mode" >&2
          warned_permission=1
        fi
        ;;
      --allow-dangerously-skip-permissions|--dangerously-skip-permissions)
        if [[ "$warned_danger" == "0" ]]; then
          printf 'warning: do not combine autopilot worktree mode with --allow-dangerously-skip-permissions or --dangerously-skip-permissions outside isolated sandboxes\n' >&2
          warned_danger=1
        fi
        ;;
      --worktree|--worktree=*|-w)
        if [[ "$warned_worktree" == "0" ]]; then
          printf 'warning: claude-autopilot-worktree.sh already provisions --worktree %s; avoid overriding it from the command line\n' "$worktree_name" >&2
          warned_worktree=1
        fi
        ;;
      --tmux|--tmux=*)
        if [[ "$warned_tmux" == "0" ]]; then
          printf 'warning: claude-autopilot-worktree.sh already manages tmux behavior via CLAUDE_AUTOPILOT_WORKTREE_TMUX; avoid overriding it from the command line\n' >&2
          warned_tmux=1
        fi
        ;;
    esac
  done
}

permission_mode="${CLAUDE_AUTOPILOT_PERMISSION_MODE:-acceptEdits}"
worktree_name="${CLAUDE_AUTOPILOT_WORKTREE_NAME:-autopilot-$(date +%Y%m%d%H%M%S)}"
tmux_mode="${CLAUDE_AUTOPILOT_WORKTREE_TMUX:-0}"
autopilot_prompt=$(cat <<'EOF'
Autopilot-worktree is an experimental bounded execution mode. Claude is running in an isolated git worktree created for this session. Keep changes scoped, validate after each meaningful step, and stop when complete or genuinely blocked. Worktree isolation is for containment and reviewability, not a reason to bypass permission safety, secret handling rules, or destructive-action guardrails. At the end, clearly summarize what should be merged, cherry-picked, or discarded.
EOF
)

printf 'warning: claude-autopilot-worktree.sh is experimental and defaults to --permission-mode %s in worktree %s\n' "$permission_mode" "$worktree_name" >&2
if [[ "$permission_mode" == "bypassPermissions" ]]; then
  printf 'warning: bypassPermissions is not part of the supported baseline; use it only in isolated sandboxes with no internet access\n' >&2
fi

warn_if_conflicting_flags "$@"

claude_args=(
  --permission-mode "$permission_mode"
  --worktree "$worktree_name"
  --append-system-prompt "$autopilot_prompt"
)

case "$tmux_mode" in
  0|false|False|FALSE|'') ;;
  1|true|True|TRUE) claude_args+=(--tmux) ;;
  *) claude_args+=(--tmux="$tmux_mode") ;;
esac

exec claude "${claude_args[@]}" "$@"