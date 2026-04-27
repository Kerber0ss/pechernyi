#!/bin/bash
# pechernyi — one-command hook installer for Claude Code
# Installs: SessionStart hook (auto-load rules) + UserPromptSubmit hook (mode tracking)
# Usage: bash hooks/install.sh
#   or:  bash <(curl -s https://raw.githubusercontent.com/Kerber0ss/pechernyi/main/hooks/install.sh)
#   or:  bash hooks/install.sh --force   (re-install over existing hooks)
set -e

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=1 ;;
  esac
done

# Detect Windows (Git Bash / MSYS / MINGW) — not WSL (WSL reports "linux-gnu")
case "$OSTYPE" in
  msys*|cygwin*|mingw*)
    echo "WARNING: Running on Windows ($OSTYPE)."
    echo "         This script works in Git Bash/MSYS but symlinks may require"
    echo "         Developer Mode or admin privileges."
    echo "         If you installed via 'claude plugin install', you don't need this script."
    echo ""
    ;;
esac

# Require node — resolve full path so hooks work in Git Bash where PATH is limited
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: 'node' is required to install the pechernyi hooks (used to merge"
  echo "       the hook config into ~/.claude/settings.json safely)."
  echo "       Install Node.js from https://nodejs.org and re-run this script."
  exit 1
fi
NODE_PATH="$(command -v node)"
# On Windows (MSYS/Git Bash), convert to a path that survives shell re-invocation
case "$OSTYPE" in
  msys*|cygwin*|mingw*)
    # Try cygpath first (available in Git Bash), fall back to raw path
    if command -v cygpath >/dev/null 2>&1; then
      NODE_PATH="$(cygpath -m "$NODE_PATH")"
    fi
    ;;
esac

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
REPO_URL="https://raw.githubusercontent.com/Kerber0ss/pechernyi/main/hooks"

HOOK_FILES=("package.json" "pechernyi-config.js" "pechernyi-activate.js" "pechernyi-mode-tracker.js" "pechernyi-statusline.sh")

# Resolve source — works from repo clone or curl pipe
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
fi

# Check if already installed (unless --force). Older installs only had two hook
# files, so require the full current set plus the hook registrations before we
# short-circuit.
ALREADY_INSTALLED=0
if [ "$FORCE" -eq 0 ]; then
  ALL_FILES_PRESENT=1
  for hook in "${HOOK_FILES[@]}"; do
    if [ ! -f "$HOOKS_DIR/$hook" ]; then
      ALL_FILES_PRESENT=0
      break
    fi
  done

  HOOKS_WIRED=0
  HAS_STATUSLINE=0
  if [ "$ALL_FILES_PRESENT" -eq 1 ] && [ -f "$SETTINGS" ]; then
    if PECHERNYI_SETTINGS="$SETTINGS" node -e "
      const fs = require('fs');
      const settings = JSON.parse(fs.readFileSync(process.env.PECHERNYI_SETTINGS, 'utf8'));
      const hasPechernyiHook = (event) =>
        Array.isArray(settings.hooks?.[event]) &&
        settings.hooks[event].some(e =>
          e.hooks && e.hooks.some(h => h.command && h.command.includes('pechernyi'))
        );
      process.exit(
        hasPechernyiHook('SessionStart') &&
        hasPechernyiHook('UserPromptSubmit') &&
        !!settings.statusLine
          ? 0
          : 1
      );
    " >/dev/null 2>&1; then
      HOOKS_WIRED=1
      HAS_STATUSLINE=1
    fi
  fi

  if [ "$ALL_FILES_PRESENT" -eq 1 ] && [ "$HOOKS_WIRED" -eq 1 ] && [ "$HAS_STATUSLINE" -eq 1 ]; then
    ALREADY_INSTALLED=1
    echo "Pechernyi hooks already installed in $HOOKS_DIR"
    echo "  Re-run with --force to overwrite: bash hooks/install.sh --force"
    echo ""
  fi
fi

if [ "$ALREADY_INSTALLED" -eq 1 ] && [ "$FORCE" -eq 0 ]; then
  echo "Nothing to do. Hooks are already in place."
  exit 0
fi

if [ "$FORCE" -eq 1 ] && [ -f "$HOOKS_DIR/pechernyi-activate.js" ]; then
  echo "Reinstalling pechernyi hooks (--force)..."
else
  echo "Installing pechernyi hooks..."
fi

# 1. Ensure hooks dir exists
mkdir -p "$HOOKS_DIR"

# 2. Copy or download hook files
for hook in "${HOOK_FILES[@]}"; do
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$hook" ]; then
    cp "$SCRIPT_DIR/$hook" "$HOOKS_DIR/$hook"
  else
    curl -fsSL "$REPO_URL/$hook" -o "$HOOKS_DIR/$hook"
  fi
  echo "  Installed: $HOOKS_DIR/$hook"
done

# Make statusline script executable
chmod +x "$HOOKS_DIR/pechernyi-statusline.sh"

# 3. Wire hooks + statusline into settings.json (idempotent)
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Back up existing settings.json before touching it
cp "$SETTINGS" "$SETTINGS.pechernyi-backup"

# Pass paths via env vars — avoids shell injection if $HOME contains single quotes
PECHERNYI_SETTINGS="$SETTINGS" PECHERNYI_HOOKS_DIR="$HOOKS_DIR" PECHERNYI_NODE_PATH="$NODE_PATH" node -e "
  const fs = require('fs');
  const settingsPath = process.env.PECHERNYI_SETTINGS;
  const hooksDir = process.env.PECHERNYI_HOOKS_DIR;
  const nodePath = process.env.PECHERNYI_NODE_PATH || 'node';
  const managedStatusLinePath = hooksDir + '/pechernyi-statusline.sh';
  const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  if (!settings.hooks) settings.hooks = {};

  function wireHook(event, scriptFile, statusMsg) {
    if (!settings.hooks[event]) settings.hooks[event] = [];
    const fullCommand = '\"' + nodePath + '\" \"' + hooksDir + '/' + scriptFile + '\"';
    let found = false;
    for (const entry of settings.hooks[event]) {
      if (!entry.hooks) continue;
      for (const h of entry.hooks) {
        if (h.command && h.command.includes('pechernyi')) {
          h.command = fullCommand;
          found = true;
        }
      }
    }
    if (!found) {
      settings.hooks[event].push({
        hooks: [{
          type: 'command',
          command: fullCommand,
          timeout: 5,
          statusMessage: statusMsg
        }]
      });
    }
  }

  wireHook('SessionStart', 'pechernyi-activate.js', 'Loading pechernyi mode...');
  wireHook('UserPromptSubmit', 'pechernyi-mode-tracker.js', 'Tracking pechernyi mode...');

  // Statusline — wire pechernyi badge (report if skipped)
  if (!settings.statusLine) {
    settings.statusLine = {
      type: 'command',
      command: 'bash \"' + managedStatusLinePath + '\"'
    };
    console.log('  Statusline badge configured.');
  } else {
    const cmd = typeof settings.statusLine === 'string'
      ? settings.statusLine
      : (settings.statusLine.command || '');
    if (cmd.includes(managedStatusLinePath)) {
      console.log('  Statusline badge already configured.');
    } else {
      console.log('  NOTE: Existing statusline detected — pechernyi badge NOT added.');
      console.log('        See hooks/README.md to add the badge to your existing statusline.');
    }
  }

  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
  console.log('  Hooks wired in settings.json');
"

echo ""
echo "Done! Restart Claude Code to activate."
echo ""
echo "What's installed:"
echo "  - SessionStart hook: auto-loads pechernyi rules every session"
echo "  - Mode tracker hook: updates statusline badge when you switch modes"
echo "    (/pechernyi lite, /pechernyi ultra, /pechernyi-commit, etc.)"
echo "  - Statusline badge: shows [ПЕЧЕРНИЙ] or [ПЕЧЕРНИЙ:УЛЬТРА] etc."
