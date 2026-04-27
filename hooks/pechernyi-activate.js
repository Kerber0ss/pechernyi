#!/usr/bin/env node
// pechernyi — Claude Code SessionStart activation hook
//
// Runs on every session start:
//   1. Writes flag file at $CLAUDE_CONFIG_DIR/.pechernyi-active (statusline reads this)
//   2. Emits pechernyi ruleset as hidden SessionStart context
//   3. Detects missing statusline config and emits setup nudge

const fs = require('fs');
const path = require('path');
const os = require('os');
const { getDefaultMode, safeWriteFlag, readFlag } = require('./pechernyi-config');

const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const settingsPath = path.join(claudeDir, 'settings.json');

// PECHERNYI_DEFAULT_MODE env var allows power users to auto-activate.
// Without it, default is 'off' — user must explicitly /pechernyi to activate.
const mode = getDefaultMode();

if (mode === 'off') {
  safeWriteFlag('off');
  process.stdout.write('OK');
  process.exit(0);
}

// 1. Write flag file
safeWriteFlag(mode);

// 2. Emit full pechernyi ruleset, filtered to the active intensity level.
//    The old 2-sentence summary was too weak — models drifted back to verbose
//    mid-conversation, especially after context compression pruned it away.
//    Full rules with examples anchor behavior much more reliably.
//
//    Reads SKILL.md at runtime so edits to the source of truth propagate
//    automatically — no hardcoded duplication to go stale.

const INDEPENDENT_MODES = new Set(['commit', 'review', 'compress']);

if (INDEPENDENT_MODES.has(mode)) {
  process.stdout.write('PECHERNYI MODE ACTIVE — level: ' + mode + '. Behavior defined by /pechernyi-' + mode + ' skill.');
  process.exit(0);
}

// Resolve the canonical label for pechernyi alias
const modeLabel = mode === 'pechernyi' ? 'pechernyi-full' : mode;

// Read SKILL.md — the single source of truth for pechernyi behavior.
// Plugin installs: use CLAUDE_PLUGIN_ROOT if available, fallback to relative path.
let skillContent = '';
const skillPath = process.env.CLAUDE_PLUGIN_ROOT
  ? path.join(process.env.CLAUDE_PLUGIN_ROOT, 'skills', 'pechernyi', 'SKILL.md')
  : path.join(__dirname, '..', 'skills', 'pechernyi', 'SKILL.md');

try {
  skillContent = fs.readFileSync(skillPath, 'utf8');
} catch (e) { /* standalone install — will use fallback below */ }

let output;

if (skillContent) {
  // Strip YAML frontmatter
  const body = skillContent.replace(/^---[\s\S]*?---\s*/, '');

  // Filter intensity table: keep header rows + only the active level's row
  const filtered = body.split('\n').reduce((acc, line) => {
    // Intensity table rows start with | **level** |
    const tableRowMatch = line.match(/^\|\s*\*\*(\S+?)\*\*\s*\|/);
    if (tableRowMatch) {
      // Keep only the active level's row (and always keep header/separator)
      if (tableRowMatch[1] === modeLabel) {
        acc.push(line);
      }
      return acc;
    }

    // Example lines start with "- level:" — keep only lines matching active level
    const exampleMatch = line.match(/^- (\S+?):\s/);
    if (exampleMatch) {
      if (exampleMatch[1] === modeLabel) {
        acc.push(line);
      }
      return acc;
    }

    acc.push(line);
    return acc;
  }, []);

  output = 'PECHERNYI MODE ACTIVE — level: ' + modeLabel + '\n\n' + filtered.join('\n');
} else {
  // Fallback when SKILL.md is not found (standalone hook install without skills dir).
  // Ukrainian fallback string as per instructions.
  output =
    'PECHERNYI MODE ACTIVE — level: ' + modeLabel + '\n\n' +
    'Відповідати стисло, як розумний печерний. Технічна суть залишається.\n' +
    'Скидати: вставні слова (ну, взагалі, фактично), люб\'язності (Звісно!, Гаразд!), хеджування (мабуть, здається).\n' +
    'Фрагменти ок. Інфінітив замість розгорнутих форм. Паттерн: [що] [дія] [причина]. [наступний крок].\n' +
    'Код-блоки незмінні. /pechernyi lite|full|ultra. Вимкнути: "стоп печерний".';
}

// 3. Detect missing statusline config — nudge Claude to help set it up
try {
  let hasStatusline = false;
  if (fs.existsSync(settingsPath)) {
    const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    if (settings.statusLine) {
      hasStatusline = true;
    }
  }

  if (!hasStatusline) {
    const isWindows = process.platform === 'win32';
    const scriptName = isWindows ? 'pechernyi-statusline.ps1' : 'pechernyi-statusline.sh';
    const scriptPath = path.join(__dirname, scriptName);
    const command = isWindows
      ? `powershell -ExecutionPolicy Bypass -File "${scriptPath}"`
      : `bash "${scriptPath}"`;
    const statusLineSnippet =
      '"statusLine": { "type": "command", "command": ' + JSON.stringify(command) + ' }';
    output += "\n\n" +
      "STATUSLINE SETUP NEEDED: The pechernyi plugin includes a statusline badge showing active mode " +
      "(e.g. [ПЕЧЕРНИЙ], [ПЕЧЕРНИЙ:УЛЬТРА]). It is not configured yet. " +
      "To enable, add this to " + path.join(claudeDir, 'settings.json') + ": " +
      statusLineSnippet + " " +
      "Proactively offer to set this up for the user on first interaction.";
  }
} catch (e) {
  // Silent fail — don't block session start over statusline detection
}

process.stdout.write(output);
