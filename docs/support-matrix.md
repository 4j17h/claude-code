# Support Matrix

This repository standardizes an org-wide Claude Code workflow with one supported baseline and a smaller set of optional integrations.

## Support tiers

### Supported baseline

The supported baseline is the part every engineering team should be able to rely on.

- Claude Code on the stable channel with the minimum version floor from `.claude/settings.json`
- Shared workflow guidance in `CLAUDE.md`
- Shared repo settings in `.claude/settings.json`
- Empty MCP baseline in `.mcp.json`
- Setup and verification scripts in `scripts/setup-macos.sh`, `scripts/setup-windows.ps1`, `scripts/verify-setup.sh`, and `scripts/verify-setup.ps1`
- Core launch modes in `scripts/claude-budget-mode.*`, `scripts/claude-batch-mode.*`, `scripts/claude-batch-json-mode.*`, `scripts/claude-batch-stream-json-mode.*`, `scripts/claude-plan-mode.*`, and `scripts/claude-api-mode.*`
- Local bootstrap files created by setup: `.env`, `CLAUDE.local.md`, `.claude/settings.local.json`

### Supported optional

These integrations are supported when explicitly enabled, but they are not required for the baseline workflow.

- `claude-usage` via `scripts/start-usage-dashboard.*`
- `code-review-graph` when installed through the setup scripts

### Experimental

These integrations stay opt-in and may need manual follow-up depending on OS, shell, or upstream changes.

- `rtk`
- `cozempic`
- `agent-browser`
- `claude-autopilot-lite.*`
- `claude-autopilot-worktree.*`

## Mode selection

- Interactive default: run `claude` after setup when you want the normal subscription or Teams workflow.
- Budget mode: use `scripts/claude-budget-mode.*` for low-stakes exploration when lower effort and earlier compaction are worth the tradeoff.
- Batch mode: use `scripts/claude-batch-mode.*` for repeatable scripted prompts and better cache reuse.
- Batch JSON mode: use `scripts/claude-batch-json-mode.*` when you want machine-readable JSON output for automation.
- Batch stream-json mode: use `scripts/claude-batch-stream-json-mode.*` when you want realtime structured output for automation.
- Plan mode: use `scripts/claude-plan-mode.*` when you want planning-first work with Claude CLI `--permission-mode plan`.
- API mode: use `scripts/claude-api-mode.*` only when you intentionally want local API credentials from `.env`.
- Autopilot-lite: use `scripts/claude-autopilot-lite.*` only as an experimental bounded execution wrapper, not as part of the required baseline.
- Autopilot-worktree: use `scripts/claude-autopilot-worktree.*` only as an experimental bounded execution wrapper with git worktree isolation.

## Permission safety

- `scripts/claude-plan-mode.*` uses `--permission-mode plan` by default.
- `scripts/claude-autopilot-lite.*` defaults to `--permission-mode acceptEdits` unless `CLAUDE_AUTOPILOT_PERMISSION_MODE` overrides it.
- `scripts/claude-autopilot-worktree.*` defaults to `--permission-mode acceptEdits` and provisions a fresh Claude worktree session unless environment variables override that behavior.
- `--allow-dangerously-skip-permissions`, `--dangerously-skip-permissions`, and `--permission-mode bypassPermissions` are outside the supported baseline and should only be used in isolated sandboxes with no internet access.

## Ownership boundaries

- Org-owned, committed files: `README.md`, `CLAUDE.md`, `.claude/settings.json`, `.mcp.json`, `.env.template`, and the `scripts/` directory.
- User-owned, local-only files: `.env`, `CLAUDE.local.md`, `.claude/settings.local.json`.
- Optional tools are never required for initial setup success.

## Verification expectations

- `scripts/verify-setup.*` should pass for the supported baseline after a user runs setup and logs in.
- `scripts/verify-setup.sh --repo-only` and `scripts/verify-setup.ps1 -RepoOnly` validate only the committed baseline for CI or preflight checks.
- Missing local bootstrap files indicate setup has not been completed on that machine.
- Missing optional tools should warn, not block the supported baseline.