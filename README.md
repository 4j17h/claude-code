# Claude Code Team Setup

This repository standardizes how engineering teams install, verify, and use Claude Code across macOS and Windows.

It is not just a Claude Code installer. It adds a managed operating layer around Claude Code so teams get:

- reproducible setup
- shared defaults and permission boundaries
- clear local-only secret handling
- a verification path for supportability
- workload-specific launch modes
- optional efficiency and observability tooling without making them mandatory

## What This Repo Solves

Standalone Claude Code is strong for individual use. This repository adds the missing team layer:

- Standard setup for macOS and Windows
- Shared policy defaults in `.claude/settings.json`
- Clear separation between committed org-owned files and machine-local files
- Verification scripts for repo preflight and machine readiness
- Defined operating modes for interactive, budget, batch, batch JSON, planning-first, and API-backed workflows
- A support model for optional tools such as `claude-usage`, `rtk`, and `code-review-graph`

## Repository Layout

- `README.md`: quick start and daily usage guide
- `CLAUDE.md`: workflow defaults, support model, and operating guidance
- `docs/support-matrix.md`: support tiers, boundaries, and mode selection
- `docs/execution-modes.md`: detailed launch-mode guidance and permission safety notes
- `scripts/`: setup, verification, launch modes, and optional dashboard entry points
- `.claude/settings.json`: shared Claude Code defaults and permission policy
- `.env.template`: local API-mode template copied to `.env` by setup

## Supported Baseline

The supported baseline includes:

- Claude Code on the stable channel with the minimum version floor from `.claude/settings.json`
- Shared repo guidance in `CLAUDE.md`
- Setup scripts for macOS and Windows
- Verification scripts for preflight and machine readiness
- Core launch modes: normal interactive use, budget mode, batch mode, batch isolated mode, batch JSON mode, batch stream-json mode, plan mode, and API mode
- Local bootstrap files created by setup: `.env`, `CLAUDE.local.md`, `.claude/settings.local.json`

Experimental launch wrapper:

- `scripts/claude-autopilot-lite.*`
- `scripts/claude-autopilot-worktree.*`

Optional tooling is supported or experimental depending on the integration. See `docs/support-matrix.md` for the exact tiering.

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/4j17h/claude-code.git
cd claude-code
```

### 2. Optional preflight check

Use repo-only verification when you want to validate the committed baseline before touching your machine-local setup.

macOS/Linux:

```bash
bash scripts/verify-setup.sh --repo-only
```

Windows PowerShell:

```powershell
.\scripts\verify-setup.ps1 -RepoOnly
```

### 3. Run setup for your OS

macOS:

```bash
bash scripts/setup-macos.sh
```

Windows PowerShell:

```powershell
.\scripts\setup-windows.ps1
```

The setup scripts:

- install or align Claude Code
- persist the local user bin directory on `PATH`
- create machine-local bootstrap files
- optionally install supported extras when requested

### 4. Log in

For the normal interactive workflow, use your Claude subscription or Teams login:

```bash
claude
```

### 5. Verify machine readiness

macOS/Linux:

```bash
bash scripts/verify-setup.sh
```

Windows PowerShell:

```powershell
.\scripts\verify-setup.ps1
```

The baseline is ready when the verify script passes the shared config checks, finds the local bootstrap files, and confirms that `claude` is available and authenticated.

## Local Files Created By Setup

Setup creates these local-only files when missing:

- `.env`: local API-mode credentials and runtime flags
- `CLAUDE.local.md`: machine-specific notes and local experiments
- `.claude/settings.local.json`: machine-local Claude overrides

These files are intentionally ignored by git and should not be committed.

## Daily Usage

For the full mode-by-mode guide, see `docs/execution-modes.md`.

### Default interactive mode

Use this for normal Claude subscription or Teams workflows.

```bash
claude
```

### Budget mode

Use this for lower-cost exploration, routine search, and narrow edits.

macOS/Linux:

```bash
bash scripts/claude-budget-mode.sh
```

Windows PowerShell:

```powershell
.\scripts\claude-budget-mode.ps1
```

Budget mode lowers effort, disables thinking, disables auto memory, disables prompt suggestions, and compacts earlier.

### Batch mode

Use this for repeatable scripted prompts or automation glue.

macOS/Linux:

```bash
bash scripts/claude-batch-mode.sh "your prompt here"
```

Windows PowerShell:

```powershell
.\scripts\claude-batch-mode.ps1 "your prompt here"
```

Batch mode uses cache-friendly pipe-mode defaults.

### Batch isolated mode

Use this when you want scripted automation with fewer surprises from local MCP, skills, or slash-command state.

macOS/Linux:

```bash
bash scripts/claude-batch-isolated-mode.sh "your prompt here"
```

Windows PowerShell:

```powershell
.\scripts\claude-batch-isolated-mode.ps1 "your prompt here"
```

This wrapper uses `--strict-mcp-config`, an explicit empty `--mcp-config`, `--disable-slash-commands`, `--exclude-dynamic-system-prompt-sections`, and `--permission-mode dontAsk` to keep automation runs more reproducible across machines.

If a prompt truly needs file reads or uploaded-file references, append `--allowedTools Read` explicitly rather than broadening the default.

### Batch JSON mode

Use this when you want machine-readable JSON output for scripts, pipelines, or automation.

macOS/Linux:

```bash
bash scripts/claude-batch-json-mode.sh "your prompt here"
```

Windows PowerShell:

```powershell
.\scripts\claude-batch-json-mode.ps1 "your prompt here"
```

Batch JSON mode uses `--output-format json` together with the same cache-friendly prompt treatment as the normal batch wrapper.

### Batch stream-json mode

Use this when you want realtime structured output for streaming consumers or automation.

macOS/Linux:

```bash
bash scripts/claude-batch-stream-json-mode.sh "your prompt here"
```

Windows PowerShell:

```powershell
.\scripts\claude-batch-stream-json-mode.ps1 "your prompt here"
```

This wrapper uses `--output-format stream-json` and `--include-partial-messages`. Add `--include-hook-events` only when the consumer actually needs Claude hook lifecycle events.

Minimal automation example:

```bash
bash scripts/claude-batch-stream-json-mode.sh "Summarize onboarding gaps in README.md" \
	| python3 -c 'import json, sys
for line in sys.stdin:
		event = json.loads(line)
		print(event.get("type", "unknown"))'
```

For production automation, prefer capturing the JSONL stream to a file and consuming it defensively, because event shapes can evolve across Claude CLI versions.

### Plan mode

Use this when you want planning-first work before any implementation. This wrapper sets Claude CLI `--permission-mode plan` and appends a planning-specific prompt overlay.

macOS/Linux:

```bash
bash scripts/claude-plan-mode.sh
```

Windows PowerShell:

```powershell
.\scripts\claude-plan-mode.ps1
```

### API mode

Use this only when you intentionally want local API credentials from `.env`.

1. Fill in `.env` using `.env.template` as the source.
2. Launch the API mode script.

macOS/Linux:

```bash
bash scripts/claude-api-mode.sh
```

Windows PowerShell:

```powershell
.\scripts\claude-api-mode.ps1
```

Subscription login remains the default path for interactive use.

### Experimental autopilot-lite mode

Use this only when you want a bounded autonomous execution wrapper on top of the supported baseline.

macOS/Linux:

```bash
bash scripts/claude-autopilot-lite.sh
```

Windows PowerShell:

```powershell
.\scripts\claude-autopilot-lite.ps1
```

Autopilot-lite is experimental. It defaults to `--permission-mode acceptEdits`, appends an execution-focused prompt overlay, and is meant to stay inside the normal team safety model rather than bypass it.

### Experimental autopilot-worktree mode

Use this when you want the same bounded autonomy model but with git worktree isolation.

macOS/Linux:

```bash
bash scripts/claude-autopilot-worktree.sh
```

Windows PowerShell:

```powershell
.\scripts\claude-autopilot-worktree.ps1
```

Autopilot-worktree is experimental. It provisions a fresh Claude worktree session, defaults to `--permission-mode acceptEdits`, and is the safer place to trial autonomous execution without running directly in the main working tree.

## Mode Selection

Use this rough decision guide:

- `claude`: normal interactive work
- `scripts/claude-budget-mode.*`: low-stakes or cost-sensitive exploration
- `scripts/claude-batch-mode.*`: scripted, repeatable prompts
- `scripts/claude-batch-isolated-mode.*`: scripted automation that should ignore ambient MCP and skills state
- `scripts/claude-batch-json-mode.*`: structured JSON output for automation
- `scripts/claude-batch-stream-json-mode.*`: realtime structured output for automation
- `scripts/claude-plan-mode.*`: planning-first work with `--permission-mode plan`
- `scripts/claude-api-mode.*`: explicit local API-key workflows
- `scripts/claude-autopilot-lite.*`: experimental bounded execution wrapper
- `scripts/claude-autopilot-worktree.*`: experimental bounded execution wrapper with worktree isolation

## Permission Mode And Safety Warnings

Some wrappers intentionally set Claude CLI permission behavior:

- `scripts/claude-batch-isolated-mode.*` uses `--permission-mode dontAsk` and an explicit empty `--mcp-config` to minimize local variability
- `scripts/claude-plan-mode.*` uses `--permission-mode plan`
- `scripts/claude-autopilot-lite.*` defaults to `--permission-mode acceptEdits`
- `scripts/claude-autopilot-worktree.*` defaults to `--permission-mode acceptEdits` and provisions a fresh worktree session

The following are not part of the supported baseline and should be treated as high-risk overrides:

- `--allow-dangerously-skip-permissions`
- `--dangerously-skip-permissions`
- `--permission-mode bypassPermissions`

Only use them in isolated sandboxes with no internet access. Do not normalize them into team defaults, shared scripts, or shared documentation as a standard operating pattern.

## Optional Tooling

Optional tools should only be enabled after the supported baseline is working.

### `claude-usage`

The setup script clones `claude-usage` by default when git and Python are available.

macOS/Linux:

```bash
bash scripts/start-usage-dashboard.sh
```

Windows PowerShell:

```powershell
.\scripts\start-usage-dashboard.ps1
```

### `rtk`

`rtk` is an experimental efficiency layer that can reduce noisy shell output before it reaches Claude. It is strongest on macOS and WSL.

Enable it by re-running setup:

macOS:

```bash
ENABLE_RTK=1 ./scripts/setup-macos.sh
```

Windows PowerShell:

```powershell
.\scripts\setup-windows.ps1 -EnableRtk
```

### `code-review-graph`

Supported optional integration for medium and large repositories.

macOS:

```bash
ENABLE_CODE_REVIEW_GRAPH=1 ./scripts/setup-macos.sh
```

Windows PowerShell:

```powershell
.\scripts\setup-windows.ps1 -EnableCodeReviewGraph
```

### Other experimental extras

- `cozempic`
- `agent-browser`

Enable them by re-running the setup script with the corresponding flag shown in the setup output.

## Verification Modes

### Repo-only verification

Use this for CI or preflight validation of committed files only.

- checks shared docs, scripts, and JSON files
- does not require `.env`, `CLAUDE.local.md`, or `.claude/settings.local.json`
- does not require Claude to be installed on the machine

### Full machine verification

Use this after setup and login.

- checks shared repo files
- checks local bootstrap files
- checks `claude` on `PATH`
- checks authentication state
- warns about optional dependencies without blocking baseline success

## Recommended Workflow Defaults

The operating model in `CLAUDE.md` assumes:

- stable startup context for better cache reuse
- early compaction instead of waiting until context is huge
- avoiding mid-session plugin or MCP churn unless you want a reset
- using `/clear` between unrelated tasks
- checking `/status`, `/context`, and `/usage` when sessions feel expensive or unusual

## Troubleshooting

If setup or verification fails:

1. Re-run repo-only verification first to separate repo issues from machine issues.
2. Re-run your OS setup script.
3. Re-run the full verify script.
4. Check whether `claude --version` and `claude auth status --text` work directly.
5. Treat optional-tool warnings separately from baseline failures.

## Ownership Boundaries

Org-owned, committed files:

- `README.md`
- `CLAUDE.md`
- `.claude/settings.json`
- `.mcp.json`
- `.env.template`
- `scripts/`
- `docs/`

User-owned, local-only files:

- `.env`
- `CLAUDE.local.md`
- `.claude/settings.local.json`

## Read More

- `CLAUDE.md` for workflow defaults and policy
- `docs/support-matrix.md` for support tiers and boundaries
- `docs/execution-modes.md` for launch modes, automation wrappers, and permission safety