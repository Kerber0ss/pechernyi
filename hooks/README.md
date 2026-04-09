# Caveman SessionStart Hook

Optional Claude Code hook that auto-loads caveman rules at session start.

## Quick Install

```bash
bash <(curl -s https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh)
```

Or from a cloned repo: `bash hooks/install.sh`

## What It Does

1. **Writes a flag file** at `~/.claude/.caveman-active` (timestamp only)
2. **Emits caveman rules** as SessionStart context so Claude sees them automatically

## How It Works

The `caveman-activate.js` hook is wired into `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/hooks/caveman-activate.js",
            "statusMessage": "Loading caveman mode..."
          }
        ]
      }
    ]
  }
}
```

## Optional: Statusline Badge

SessionStart hook stdout is hidden system context — Claude sees it, but you don't. The flag file bridges that gap so a statusline script can show a `[CAVEMAN]` badge.

Add this to your statusline script:

```bash
# Caveman mode badge
caveman_text=""
caveman_flag="$HOME/.claude/.caveman-active"
if [ -f "$caveman_flag" ]; then
  caveman_text="\033[38;5;172m[CAVEMAN]\033[0m"
fi
```

Or in Node:

```js
const fs = require('fs');
const path = require('path');
const os = require('os');

let cavemanBadge = '';
const cavemanFlag = path.join(os.homedir(), '.claude', '.caveman-active');
if (fs.existsSync(cavemanFlag)) {
  cavemanBadge = '\x1b[1;38;5;208m[CAVEMAN]\x1b[0m | ';
}
```

## Uninstall

1. Remove `~/.claude/hooks/caveman-activate.js`
2. Remove the SessionStart entry from `~/.claude/settings.json`
3. Delete `~/.claude/.caveman-active`
