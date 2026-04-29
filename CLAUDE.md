# Claude Code Team Setup

## Purpose
- This repository standardizes a fast, low-friction Claude Code setup for macOS and Windows.
- Prefer current stable Claude Code with a known-good minimum version floor.
- Do not rely on downgrade pins or User-Agent spoofing as a default workflow.

## Support model
- The supported baseline is official Claude Code plus the shared settings, setup scripts, verify scripts, and launch modes in this repository.
- Local bootstrap files are machine-specific and created by the setup scripts: `.env`, `CLAUDE.local.md`, and `.claude/settings.local.json`.
- Optional integrations are tiered separately from the baseline so they do not block initial adoption.
- See `docs/support-matrix.md` for support tiers, ownership boundaries, and mode selection.
- See `docs/execution-modes.md` for launch-mode guidance and permission safety notes.

## Shared workflow defaults
- Keep startup context stable for better cache reuse.
- Avoid changing models, plugins, or MCP servers in the middle of a session unless you need a deliberate reset.
- Use `/compact` early, not heroically late. The project baseline targets earlier auto-compaction on purpose.
- Use `/clear` between unrelated tasks.
- Check `/context`, `/usage`, and `/status` when a session feels expensive or strange.

## Effort guidance
- Use `low` or `medium` for rote search, file discovery, formatting, and narrow edits.
- Use `high` for debugging, refactors, and multi-file implementation work.
- Use `xhigh` for ambiguous problems, architecture decisions, and tricky root-cause analysis.
- Avoid raising effort for mechanical tasks just because the button exists.

## Cache and context hygiene
- Prefer stable prompts and stable tools for repeat workflows.
- For scripted multi-user runs, prefer `claude -p --exclude-dynamic-system-prompt-sections`.
- Use `scripts/claude-batch-mode.*` when you want that cache-friendly pipe-mode pattern standardized for the team.
- Use `scripts/claude-batch-commit-mode.*` when you want a cheap one-shot helper for commit messages from staged diffs.
- Use `scripts/claude-batch-isolated-mode.*` when automation should ignore local MCP and skills variance for more reproducible runs.
- Use `scripts/claude-batch-json-mode.*` when you want machine-readable batch output for automation.
- Use `scripts/claude-batch-stream-json-mode.*` when you want realtime structured batch output for automation.
- Use `scripts/claude-plan-mode.*` when you want planning-first sessions with Claude CLI `--permission-mode plan`.
- Prefer text-native context: source files, diffs, logs, CLI output, and MCP resources.
- Avoid screenshots, PDFs, and large pasted blobs unless layout or rendering is the point.

## Execution modes
- Use `scripts/claude-autopilot-lite.*` only as an experimental bounded execution wrapper.
- Use `scripts/claude-autopilot-worktree.*` only as an experimental bounded execution wrapper with worktree isolation.
- Do not normalize `--allow-dangerously-skip-permissions`, `--dangerously-skip-permissions`, or `--permission-mode bypassPermissions` into the team baseline; those belong only in isolated sandboxes with no internet access.

## Auth and secrets
- Subscription login is the default path for interactive use.
- Anthropic API mode is optional and local-only.
- Keep API keys in local files only (`.env`, `.claude/settings.local.json`, `CLAUDE.local.md`).
- Never put secrets in shared settings, shared rules, or committed scripts.

## Optional tooling
- Usage monitoring lives behind `scripts/start-usage-dashboard.*`.
- Budget mode lives behind `scripts/claude-budget-mode.*` and is the cleanest official-Claude version of the "poor mode" idea: low effort, no extended thinking, no auto memory, no prompt suggestions, and earlier compaction for cheaper exploratory work.
- RTK is opt-in. It is strongest on macOS and WSL; on native Windows, use it explicitly because hook mode is limited.
- code-review-graph is opt-in and most useful on medium/large repositories.
- Cozempic is experimental and only for people who run long interactive sessions.
- agent-browser is opt-in for web automation and UI-heavy debugging.

## Team bootstrap flow
- Clone the repository.
- Optional preflight: run `scripts/verify-setup.sh --repo-only` or `scripts/verify-setup.ps1 -RepoOnly` to validate the committed baseline.
- Run the setup script for your OS.
- The setup scripts persist the common user-bin directory (`~/.local/bin` on macOS, `%USERPROFILE%\.local\bin` on Windows) so fresh terminals can find `claude`.
- Log in with your Claude subscription unless you intentionally choose API mode.
- Use `scripts/verify-setup.*` to confirm the supported baseline after setup.
- Use budget mode for low-stakes exploration or when you are close to usage limits.
- Use batch mode for repeatable scripted prompts or automation glue.
- Use batch commit mode when you want a low-cost commit-message draft from staged changes.
- Use batch isolated mode when automation should stay stable even if local MCP or skills state differs across machines.
- Use batch stream-json mode for realtime automation or streaming integrations.
- Use plan mode when you want planning-first work without immediately switching into execution.
- Optional tools should be enabled only after the baseline is working.
