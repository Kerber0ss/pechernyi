#!/bin/bash
# caveman — one-command SessionStart hook installer for Claude Code
# Usage: bash hooks/install.sh
#   or:  bash <(curl -s https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh)
set -e

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_NAME="caveman-activate.js"

# Resolve the hook source — works from repo clone or curl pipe
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/$HOOK_NAME" ]; then
  HOOK_SRC="$SCRIPT_DIR/$HOOK_NAME"
else
  # Running via curl — download the hook
  HOOK_SRC=""
fi

echo "Installing caveman SessionStart hook..."

# 1. Ensure hooks dir exists
mkdir -p "$HOOKS_DIR"

# 2. Copy or download the hook file
if [ -n "$HOOK_SRC" ]; then
  cp "$HOOK_SRC" "$HOOKS_DIR/$HOOK_NAME"
else
  curl -fsSL "https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/$HOOK_NAME" \
    -o "$HOOKS_DIR/$HOOK_NAME"
fi
echo "  Hook installed: $HOOKS_DIR/$HOOK_NAME"

# 3. Add SessionStart hook to settings.json (idempotent)
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Check if caveman hook is already wired up
if grep -q "caveman-activate" "$SETTINGS" 2>/dev/null; then
  echo "  Hook already in settings.json — skipping"
else
  # Use node (available since Claude Code requires it) to merge the hook config
  node -e "
    const fs = require('fs');
    const settings = JSON.parse(fs.readFileSync('$SETTINGS', 'utf8'));
    if (!settings.hooks) settings.hooks = {};
    if (!settings.hooks.SessionStart) settings.hooks.SessionStart = [];

    const hookEntry = {
      hooks: [{
        type: 'command',
        command: 'node $HOOKS_DIR/$HOOK_NAME',
        statusMessage: 'Loading caveman mode...'
      }]
    };

    // Don't add if already present
    const exists = settings.hooks.SessionStart.some(e =>
      e.hooks && e.hooks.some(h => h.command && h.command.includes('caveman'))
    );
    if (!exists) {
      settings.hooks.SessionStart.push(hookEntry);
    }

    fs.writeFileSync('$SETTINGS', JSON.stringify(settings, null, 2) + '\n');
  "
  echo "  SessionStart hook added to settings.json"
fi

echo ""
echo "Done! Restart Claude Code to activate."
echo "The hook will auto-load caveman rules every session."
echo ""
echo "Optional: Add a [CAVEMAN] badge to your statusline."
echo "See: https://github.com/JuliusBrussee/caveman/blob/main/hooks/README.md"
