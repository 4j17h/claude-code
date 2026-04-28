#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

CLAUDE_CHANNEL="${CLAUDE_CHANNEL:-stable}"
ENABLE_API_MODE="${ENABLE_API_MODE:-0}"
ENABLE_RTK="${ENABLE_RTK:-0}"
ENABLE_COZEMPIC="${ENABLE_COZEMPIC:-0}"
ENABLE_CODE_REVIEW_GRAPH="${ENABLE_CODE_REVIEW_GRAPH:-0}"
ENABLE_AGENT_BROWSER="${ENABLE_AGENT_BROWSER:-0}"
INSTALL_CLAUDE_USAGE="${INSTALL_CLAUDE_USAGE:-1}"

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

prepend_path() {
  local path_entry="$1"
  [[ -d "$path_entry" ]] || return 1

  case ":$PATH:" in
    *":$path_entry:"*) ;;
    *) export PATH="$path_entry:$PATH" ;;
  esac

  hash -r
}

persist_path_for_shell() {
  local file="$1"
  local path_entry="$2"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -Fq "$path_entry" "$file"; then
    return
  fi

  printf '\nexport PATH="%s:$PATH"\n' "$path_entry" >> "$file"
  log "Added $path_entry to $file"
}

ensure_user_path_entry() {
  local path_entry="$1"

  prepend_path "$path_entry" || return 1
  persist_path_for_shell "$HOME/.zprofile" "$path_entry"
  persist_path_for_shell "$HOME/.zshrc" "$path_entry"
  persist_path_for_shell "$HOME/.bash_profile" "$path_entry"
  persist_path_for_shell "$HOME/.bashrc" "$path_entry"
}

ensure_git() {
  if have git; then
    return
  fi

  if have brew; then
    log "Installing git via Homebrew"
    brew install git
    return
  fi

  die "Git is required. Install Xcode Command Line Tools or Homebrew and re-run setup."
}

ensure_python3() {
  if ! have python3; then
    warn "Python 3 is missing. claude-usage will be skipped until Python 3 is installed."
  fi
}

ensure_node() {
  if ! have npm; then
    warn "Node/npm is missing. Skipping the optional agent-browser install."
    return 1
  fi
}

ensure_claude() {
  if ! have claude; then
    log "Installing Claude Code with the native macOS installer"
    curl -fsSL https://claude.ai/install.sh | bash
  fi

  ensure_user_path_entry "$HOME/.local/bin" || true

  have claude || die "Claude Code was not found after installation."

  log "Ensuring Claude Code follows the ${CLAUDE_CHANNEL} channel"
  claude install "$CLAUDE_CHANNEL" || warn "claude install ${CLAUDE_CHANNEL} failed; keeping the current install"
}

ensure_uv() {
  if have uv; then
    return
  fi

  if have brew; then
    log "Installing uv via Homebrew"
    brew install uv
  else
    log "Installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi

  ensure_user_path_entry "$HOME/.local/bin" || true

  have uv || warn "uv is not on PATH yet. Restart your shell if later tool installs fail."
}

ensure_local_files() {
  mkdir -p "$REPO_ROOT/.claude"

  if [[ ! -f "$REPO_ROOT/.env" ]]; then
    log "Creating local .env placeholder"
    cat > "$REPO_ROOT/.env" <<'EOF'
# Local-only Anthropic API mode.
# Leave blank if you use Claude subscription login instead.
ANTHROPIC_API_KEY=

# Optional for scripted subscription auth instead of browser login.
# CLAUDE_CODE_OAUTH_TOKEN=

# Optional for API-mode automation. 1-hour cache writes cost more than 5-minute writes.
# ENABLE_PROMPT_CACHING_1H=1
EOF
  fi

  if [[ ! -f "$REPO_ROOT/.claude/settings.local.json" ]]; then
    log "Creating .claude/settings.local.json"
    cat > "$REPO_ROOT/.claude/settings.local.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {}
}
EOF
  fi

  if [[ ! -f "$REPO_ROOT/CLAUDE.local.md" ]]; then
    log "Creating CLAUDE.local.md"
    cat > "$REPO_ROOT/CLAUDE.local.md" <<'EOF'
# Local notes

- Add personal workflow notes here.
- Keep machine-specific paths, proxies, and experiments in this file.
- Do not commit this file.
EOF
  fi
}

install_claude_usage() {
  [[ "$INSTALL_CLAUDE_USAGE" == "1" ]] || return

  ensure_git
  ensure_python3

  if ! have python3; then
    return
  fi

  local tool_dir="$REPO_ROOT/.tools/claude-usage"
  mkdir -p "$REPO_ROOT/.tools"

  if [[ ! -d "$tool_dir/.git" ]]; then
    log "Cloning claude-usage"
    git clone https://github.com/phuryn/claude-usage "$tool_dir"
  else
    log "Updating claude-usage"
    git -C "$tool_dir" pull --ff-only
  fi
}

install_rtk() {
  [[ "$ENABLE_RTK" == "1" ]] || return

  if ! have rtk; then
    if have brew; then
      log "Installing RTK via Homebrew"
      brew install rtk
    else
      log "Installing RTK"
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    fi
  fi

  ensure_user_path_entry "$HOME/.local/bin" || true

  if have rtk; then
    log "Initializing RTK for Claude Code"
    RTK_TELEMETRY_DISABLED=1 rtk init -g --auto-patch || warn "RTK init needs manual follow-up"
  else
    warn "RTK could not be installed automatically"
  fi
}

install_cozempic() {
  [[ "$ENABLE_COZEMPIC" == "1" ]] || return

  ensure_uv

  if ! have uv; then
    warn "uv is required for the optional Cozempic install"
    return
  fi

  if ! have cozempic; then
    log "Installing Cozempic via uv"
    uv tool install cozempic || warn "Cozempic install failed"
  fi

  ensure_user_path_entry "$HOME/.local/bin" || true

  if have cozempic; then
    log "Initializing Cozempic"
    COZEMPIC_NO_TELEMETRY=1 cozempic init || warn "Cozempic init needs manual follow-up"
  fi
}

install_code_review_graph() {
  [[ "$ENABLE_CODE_REVIEW_GRAPH" == "1" ]] || return

  ensure_uv

  if ! have uv; then
    warn "uv is required for the optional code-review-graph install"
    return
  fi

  if ! have code-review-graph; then
    log "Installing code-review-graph via uv"
    uv tool install code-review-graph || warn "code-review-graph install failed"
  fi

  ensure_user_path_entry "$HOME/.local/bin" || true

  if have code-review-graph; then
    log "Configuring code-review-graph for Claude Code"
    code-review-graph install --platform claude-code || warn "code-review-graph install needs manual follow-up"
  fi
}

install_agent_browser() {
  [[ "$ENABLE_AGENT_BROWSER" == "1" ]] || return

  if have brew; then
    log "Installing agent-browser via Homebrew"
    brew install agent-browser || warn "agent-browser Homebrew install failed"
  else
    ensure_node || return
    log "Installing agent-browser via npm"
    npm install -g agent-browser
  fi

  if have agent-browser; then
    log "Installing agent-browser browser runtime"
    agent-browser install || warn "agent-browser install needs manual follow-up"
  else
    warn "agent-browser binary is not available on PATH"
    return
  fi

  if have npx; then
    log "Adding the optional agent-browser Claude skill stub"
    npx skills add vercel-labs/agent-browser || warn "Could not add the agent-browser Claude skill"
  fi
}

print_next_steps() {
  cat <<EOF

Setup complete.

The setup script adds ~/.local/bin to the current shell and common shell startup files so new terminals can find claude automatically.

Next steps:
  1. Log in with your preferred auth mode:
     - Subscription / Teams: claude
     - Optional API mode: $REPO_ROOT/scripts/claude-api-mode.sh
     - Optional budget mode: $REPO_ROOT/scripts/claude-budget-mode.sh
     - Optional batch mode: $REPO_ROOT/scripts/claude-batch-mode.sh
  2. Verify the setup:
     - $REPO_ROOT/scripts/verify-setup.sh
  3. Optional extras can be toggled by re-running setup with flags, for example:
     - ENABLE_RTK=1 ./scripts/setup-macos.sh
     - ENABLE_CODE_REVIEW_GRAPH=1 ./scripts/setup-macos.sh
     - ENABLE_COZEMPIC=1 ./scripts/setup-macos.sh
     - ENABLE_AGENT_BROWSER=1 ./scripts/setup-macos.sh

If you enabled API mode, fill in $REPO_ROOT/.env before launching Claude.
EOF
}

main() {
  ensure_claude
  ensure_local_files
  install_claude_usage
  install_rtk
  install_cozempic
  install_code_review_graph
  install_agent_browser

  if [[ "$ENABLE_API_MODE" == "1" ]]; then
    log "API mode requested"
    warn "Fill in $REPO_ROOT/.env before using scripts/claude-api-mode.sh"
  fi

  print_next_steps
}

main "$@"
