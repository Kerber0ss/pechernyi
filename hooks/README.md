# Caveman Hooks

These hooks are **bundled with the pechernyi plugin** and activate automatically when the plugin is installed. No manual setup required.

If you installed pechernyi standalone (without the plugin), you can use `bash hooks/install.sh` to wire them into your settings.json manually.

## What's Included

### `pechernyi-activate.js` — SessionStart hook

- Runs once when Claude Code starts
- Writes `full` to `~/.claude/.pechernyi-active` (flag file)
- Emits pechernyi rules as hidden SessionStart context
- Detects missing statusline config and emits setup nudge (Claude will offer to help)

### `pechernyi-mode-tracker.js` — UserPromptSubmit hook

- Fires on every user prompt, checks for `/pechernyi` commands
- Writes the active mode to the flag file when a pechernyi command is detected
- Supports: `full`, `lite`, `ultra`, `wenyan`, `wenyan-lite`, `wenyan-ultra`, `commit`, `review`, `compress`

### `pechernyi-statusline.sh` / `pechernyi-statusline.ps1` — Statusline badge script

- Reads `~/.claude/.pechernyi-active` and outputs a colored badge
- Shows `[ПЕЧЕРНИЙ]`, `[ПЕЧЕРНИЙ:УЛЬТРА]`, `[PECHERNYI:WENYAN]`, etc.

## Statusline Badge

The statusline badge shows which pechernyi mode is active directly in your Claude Code status bar.

**Plugin users:** If you do not already have a `statusLine` configured, Claude will detect that on your first session after install and offer to set it up for you. Accept and you're done.

If you already have a custom statusline, pechernyi does not overwrite it and Claude stays quiet. Add the badge snippet to your existing script instead.

**Standalone users:** `install.sh` / `install.ps1` wires the statusline automatically if you do not already have a custom statusline. If you do, the installer leaves it alone and prints the merge note.

**Manual setup:** If you need to configure it yourself, add one of these to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/pechernyi-statusline.sh"
  }
}
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -ExecutionPolicy Bypass -File C:\\path\\to\\pechernyi-statusline.ps1"
  }
}
```

Replace the path with the actual script location (e.g. `~/.claude/hooks/` for standalone installs, or the plugin install directory for plugin installs).

**Custom statusline:** If you already have a statusline script, add this snippet to it:

```bash
pechernyi_text=""
pechernyi_flag="$HOME/.claude/.pechernyi-active"
if [ -f "$pechernyi_flag" ]; then
  pechernyi_mode=$(cat "$pechernyi_flag" 2>/dev/null)
  if [ "$pechernyi_mode" = "full" ] || [ -z "$pechernyi_mode" ]; then
    pechernyi_text=$'\033[38;5;172m[ПЕЧЕРНИЙ]\033[0m'
  else
    pechernyi_suffix=$(echo "$pechernyi_mode" | tr '[:lower:]' '[:upper:]')
    pechernyi_text=$'\033[38;5;172m[PECHERNYI:'"${pechernyi_suffix}"$']\033[0m'
  fi
fi
```

Badge examples:
- `/pechernyi` → `[ПЕЧЕРНИЙ]`
- `/pechernyi ultra` → `[ПЕЧЕРНИЙ:УЛЬТРА]`
- `/pechernyi wenyan` → `[PECHERNYI:WENYAN]`
- `/pechernyi-commit` → `[PECHERNYI:COMMIT]`
- `/pechernyi-review` → `[PECHERNYI:REVIEW]`

## How It Works

```
SessionStart hook ──writes "full"──▶ ~/.claude/.pechernyi-active ◀──writes mode── UserPromptSubmit hook
                                              │
                                           reads
                                              ▼
                                     Statusline script
                                    [ПЕЧЕРНИЙ:УЛЬТРА] │ ...
```

SessionStart stdout is injected as hidden system context — Claude sees it, users don't. The statusline runs as a separate process. The flag file is the bridge.

## Uninstall

If installed via plugin: disable the plugin — hooks deactivate automatically.

If installed via `install.sh`:
```bash
bash hooks/uninstall.sh
```

Or manually:
1. Remove `~/.claude/hooks/pechernyi-activate.js`, `~/.claude/hooks/pechernyi-mode-tracker.js`, and the matching statusline script (`pechernyi-statusline.sh` on macOS/Linux or `pechernyi-statusline.ps1` on Windows)
2. Remove the SessionStart, UserPromptSubmit, and statusLine entries from `~/.claude/settings.json`
3. Delete `~/.claude/.pechernyi-active`
