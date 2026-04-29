# Execution Modes

This repository standardizes a small set of Claude Code launch modes so teams can choose the right execution pattern without inventing local wrappers or unsafe defaults.

## Baseline modes

These modes are part of the supported baseline.

### Interactive

- Command: `claude`
- Use when: normal subscription or Teams-based interactive work
- Notes: this is the default day-to-day mode

### Budget mode

- Scripts: `scripts/claude-budget-mode.sh`, `scripts/claude-budget-mode.ps1`
- Use when: low-stakes exploration, routine search, and narrow edits
- Behavior: lower effort, disables thinking, disables auto memory, disables prompt suggestions, compacts earlier

### Batch mode

- Scripts: `scripts/claude-batch-mode.sh`, `scripts/claude-batch-mode.ps1`
- Use when: repeatable scripted prompts where text output is enough
- Behavior: `claude -p --exclude-dynamic-system-prompt-sections`

### Batch JSON mode

- Scripts: `scripts/claude-batch-json-mode.sh`, `scripts/claude-batch-json-mode.ps1`
- Use when: machine-readable single-result output for scripts and automation
- Behavior: `claude -p --output-format json --exclude-dynamic-system-prompt-sections`

### Batch stream-json mode

- Scripts: `scripts/claude-batch-stream-json-mode.sh`, `scripts/claude-batch-stream-json-mode.ps1`
- Use when: realtime automation or consumers that want structured streamed events
- Behavior: `claude -p --output-format stream-json --include-partial-messages --exclude-dynamic-system-prompt-sections`
- Notes: if you need hook lifecycle events too, append `--include-hook-events`

### Plan mode

- Scripts: `scripts/claude-plan-mode.sh`, `scripts/claude-plan-mode.ps1`
- Use when: planning-first work before implementation
- Behavior: uses `--permission-mode plan` and adds a planning-specific system prompt overlay
- Notes: this is the recommended mode for vague or high-ambiguity work that should not immediately turn into code changes

### API mode

- Scripts: `scripts/claude-api-mode.sh`, `scripts/claude-api-mode.ps1`
- Use when: you intentionally want local API credentials from `.env`
- Notes: subscription login remains the default path for interactive work

## Experimental modes

These modes are intentionally outside the required baseline.

### Autopilot-lite

- Scripts: `scripts/claude-autopilot-lite.sh`, `scripts/claude-autopilot-lite.ps1`
- Use when: you want bounded autonomous execution in the current working tree
- Default permission mode: `acceptEdits`
- Notes: starts with a brief plan, executes in small steps, validates after changes, and warns if dangerous permission bypass flags are passed

### Autopilot-worktree

- Scripts: `scripts/claude-autopilot-worktree.sh`, `scripts/claude-autopilot-worktree.ps1`
- Use when: you want bounded autonomous execution with git worktree isolation
- Default permission mode: `acceptEdits`
- Notes: creates a fresh worktree for the session, keeps the current working tree cleaner, and is the safer place to experiment before normalizing any autonomous workflow

Environment variables:

- `CLAUDE_AUTOPILOT_PERMISSION_MODE`: override the default permission mode for autopilot wrappers
- `CLAUDE_AUTOPILOT_WORKTREE_NAME`: set an explicit worktree name instead of the timestamped default
- `CLAUDE_AUTOPILOT_WORKTREE_TMUX`: set to `1` or `true` for `--tmux`, or set another value such as `classic` for `--tmux=<value>`

## Safety model

Permission behavior is part of the managed operating model.

- `scripts/claude-plan-mode.*` uses `--permission-mode plan`
- `scripts/claude-autopilot-lite.*` and `scripts/claude-autopilot-worktree.*` default to `--permission-mode acceptEdits`

The following are not part of the supported baseline and should be treated as high-risk overrides:

- `--allow-dangerously-skip-permissions`
- `--dangerously-skip-permissions`
- `--permission-mode bypassPermissions`

Only use them in isolated sandboxes with no internet access. Do not normalize them into shared team defaults or shared wrapper scripts.

## Suggested selection guide

- Use `claude` for normal interactive work.
- Use budget mode for low-cost exploration.
- Use batch mode when you want text output from a scripted call.
- Use batch JSON mode when a script needs a single structured result.
- Use batch stream-json mode when a script needs realtime structured events.
- Use plan mode when the right first step is analysis, clarification, and planning rather than editing.
- Use autopilot-lite only for experimental bounded autonomy in the current tree.
- Use autopilot-worktree when you want the same autonomy model with git worktree isolation.

## Example prompts

These examples are intentionally simple and map to the kinds of tasks teams usually run through each mode.

| Mode | Example |
| --- | --- |
| Interactive | `claude` then ask `Review README.md and tell me what is still unclear for first-time users.` |
| Budget | `bash scripts/claude-budget-mode.sh "List low-risk cleanup opportunities in README.md without editing files."` |
| Batch | `bash scripts/claude-batch-mode.sh "Summarize docs/support-matrix.md in 5 bullets for an onboarding email."` |
| Batch JSON | `bash scripts/claude-batch-json-mode.sh "Return a JSON object with keys baseline, optional, and experimental summarizing docs/support-matrix.md."` |
| Batch stream-json | `bash scripts/claude-batch-stream-json-mode.sh "Stream a structured review of README.md and docs/execution-modes.md for onboarding gaps."` |
| Plan | `bash scripts/claude-plan-mode.sh "Plan a Windows rollout for this repo and list risks, rollout gates, and validation steps."` |
| API | `bash scripts/claude-api-mode.sh "Summarize the last README changes for release notes."` |
| Autopilot-lite | `bash scripts/claude-autopilot-lite.sh "Tighten README wording, validate docs, and stop when the doc slice is complete."` |
| Autopilot-worktree | `bash scripts/claude-autopilot-worktree.sh "Refactor the verification docs in an isolated worktree and verify the result before stopping."` |