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

extract_claude_checksum() {
  local manifest_json="$1"
  local platform="$2"
  local normalized_json

  normalized_json="$(printf '%s' "$manifest_json" | tr -d '\n\r\t' | sed 's/ \+/ /g')"
  if [[ $normalized_json =~ \"$platform\"[^}]*\"checksum\"[[:space:]]*:[[:space:]]*\"([a-f0-9]{64})\" ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

detect_claude_platform() {
  local arch

  case "$(uname -m)" in
    x86_64|amd64) arch="x64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) die "Unsupported macOS architecture: $(uname -m)" ;;
  esac

  if [[ "$arch" == "x64" ]] && [[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" == "1" ]]; then
    arch="arm64"
  fi

  printf 'darwin-%s\n' "$arch"
}

install_claude_binary_fallback() {
  local download_base_url="https://downloads.claude.ai/claude-code-releases"
  local version platform manifest_json checksum tmp_binary target_binary actual_checksum

  platform="$(detect_claude_platform)"
  version="$(curl -fsSL "$download_base_url/latest")" || return 1
  manifest_json="$(curl -fsSL "$download_base_url/$version/manifest.json")" || return 1
  checksum="$(extract_claude_checksum "$manifest_json" "$platform")" || return 1

  target_binary="$HOME/.local/bin/claude"
  tmp_binary="$(mktemp "$HOME/.local/bin/claude.tmp.XXXXXX")"

  if ! curl -fsSL -o "$tmp_binary" "$download_base_url/$version/$platform/claude"; then
    rm -f "$tmp_binary"
    return 1
  fi

  actual_checksum="$(shasum -a 256 "$tmp_binary" | cut -d' ' -f1)"
  if [[ "$actual_checksum" != "$checksum" ]]; then
    warn "Downloaded Claude binary checksum did not match the release manifest"
    rm -f "$tmp_binary"
    return 1
  fi

  chmod +x "$tmp_binary"
  mv "$tmp_binary" "$target_binary"
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
  mkdir -p "$HOME/.local/bin"

  if ! have claude; then
    log "Installing Claude Code with the native macOS installer"
    if ! curl -fsSL https://claude.ai/install.sh | bash; then
      warn "Native Claude installer failed; attempting direct binary fallback"
    fi
  fi

  ensure_user_path_entry "$HOME/.local/bin" || true

  if ! have claude; then
    warn "Native installer did not produce a usable claude launcher; downloading the official Claude binary directly"
    install_claude_binary_fallback || die "Claude Code was not found after installation."
    ensure_user_path_entry "$HOME/.local/bin" || true
  fi

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
    log "Creating local .env from .env.template"
    cp "$REPO_ROOT/.env.template" "$REPO_ROOT/.env"
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
  if [[ "$INSTALL_CLAUDE_USAGE" != "1" ]]; then
    return 0
  fi

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
  if [[ "$ENABLE_RTK" != "1" ]]; then
    return 0
  fi

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
  if [[ "$ENABLE_COZEMPIC" != "1" ]]; then
    return 0
  fi

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
  if [[ "$ENABLE_CODE_REVIEW_GRAPH" != "1" ]]; then
    return 0
  fi

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
  if [[ "$ENABLE_AGENT_BROWSER" != "1" ]]; then
    return 0
  fi

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
