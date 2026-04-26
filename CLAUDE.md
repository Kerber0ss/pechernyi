# CLAUDE.md — pechernyi architecture

## Overview
pechernyi is a token-compression system for AI agents. It integrates with Claude Code via a plugin/hook system and with opencode via `AGENTS.md`.

## Integration Points

### Claude Code (Plugin System)
- **Hooks**: Uses `SessionStart` and `UserPromptSubmit` hooks to inject rules and track modes.
- **Flag File**: Communication between hooks happens via a flag file located at `$CLAUDE_CONFIG_DIR/.pechernyi-active` (fallback: `~/.claude/.pechernyi-active`). Mode names in the flag file are Latin (e.g., `ultra`).
- **Statusline**: Displays badge `[ПЕЧЕРНИЙ]` in the Claude Code status bar.

### opencode
- **AGENTS.md**: References core skill files.

### npx skills
- Skill files are located in the `skills/` directory and can be added to various agents.

## Hook Dependency Chain
1. `pechernyi-config.js` (shared): Resolves configuration and handles safe flag writes.
2. `pechernyi-activate.js` (SessionStart): Injects initial system context and ensures flag file exists.
3. `pechernyi-mode-tracker.js` (UserPromptSubmit): Handles mode switching (e.g., `/pechernyi ultra`) and deactivation.

## VALID_MODES
The system supports the following modes, defined in 4 key locations (hooks, skills, rules):
`['off', 'lite', 'full', 'ultra', 'commit', 'review', 'compress']`

## Project Ownership
Owner: Kerber0ss
