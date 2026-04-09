# Caveman Hooks

Optional Claude Code hooks that auto-load caveman rules and track which mode is active in your statusline.

## Quick Install

```bash
bash <(curl -s https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh)
```

Or from a cloned repo: `bash hooks/install.sh`

## What Gets Installed

### `caveman-activate.js` — SessionStart hook

- Runs once when Claude Code starts
- Writes `full` to `~/.claude/.caveman-active` (flag file)
- Emits caveman rules as hidden SessionStart context

### `caveman-mode-tracker.js` — PostToolUse hook

- Fires after any Skill tool invocation
- Detects caveman-related skills and writes the active mode to the flag file
- Supports: `full`, `lite`, `ultra`, `wenyan`, `wenyan-lite`, `wenyan-ultra`, `commit`, `review`, `compress`

## Statusline Badge

The flag file bridges the gap between hooks (which Claude sees) and your statusline (which you see). Add this to your statusline script to show which mode is active:

```bash
caveman_text=""
caveman_flag="$HOME/.claude/.caveman-active"
if [ -f "$caveman_flag" ]; then
  caveman_mode=$(cat "$caveman_flag" 2>/dev/null)
  if [ "$caveman_mode" = "full" ] || [ -z "$caveman_mode" ]; then
    caveman_text="\033[38;5;172m[CAVEMAN]\033[0m"
  else
    caveman_suffix=$(echo "$caveman_mode" | tr '[:lower:]' '[:upper:]')
    caveman_text="\033[38;5;172m[CAVEMAN:${caveman_suffix}]\033[0m"
  fi
fi
```

Badge examples:
- `/caveman` → `[CAVEMAN]`
- `/caveman ultra` → `[CAVEMAN:ULTRA]`
- `/caveman wenyan` → `[CAVEMAN:WENYAN]`
- `/caveman-commit` → `[CAVEMAN:COMMIT]`
- `/caveman-review` → `[CAVEMAN:REVIEW]`

## How It Works

```
SessionStart hook ──writes "full"──▶ ~/.claude/.caveman-active ◀──writes mode── PostToolUse hook
                                              │
                                           reads
                                              ▼
                                     Statusline script
                                    [CAVEMAN:ULTRA] │ ...
```

SessionStart stdout is injected as hidden system context — Claude sees it, users don't. The statusline runs as a separate process. The flag file is the bridge.

## Uninstall

1. Remove `~/.claude/hooks/caveman-activate.js` and `~/.claude/hooks/caveman-mode-tracker.js`
2. Remove the SessionStart and PostToolUse entries from `~/.claude/settings.json`
3. Delete `~/.claude/.caveman-active`
