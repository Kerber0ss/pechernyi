#!/usr/bin/env node
// pechernyi — UserPromptSubmit hook: /pechernyi commands + Ukrainian triggers

const fs = require('fs');
const path = require('path');
const os = require('os');
const { getDefaultMode, safeWriteFlag, readFlag } = require('./pechernyi-config');

const flagPath = path.join(
  process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude'),
  '.pechernyi-active'
);

const activationRegex = /(активуй|увімкни|запусти|говори\s+як).*печерний/i;
const shortModeRegex = /(менше\s+токен|коротко|стисло|печерний\s+режим)/i;
const deactivationRegex = /(стоп|вимкни|деактивуй).*печерний/i;
const normalModeRegex = /звичайний\s+режим/i;
const slashRegex = /^\/pechernyi(?:\s+(lite|full|ultra))?$/i;

let input = '';
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const prompt = (data.prompt || '').trim();
    const promptLower = prompt.toLowerCase();

    if (deactivationRegex.test(prompt) || normalModeRegex.test(prompt)) {
      try { fs.unlinkSync(flagPath); } catch (e) {}
      process.exit(0);
    }

    const slashMatch = promptLower.match(slashRegex);
    if (slashMatch) {
      const arg = slashMatch[1] || null;
      let mode;
      if (arg === 'lite') mode = 'lite';
      else if (arg === 'ultra') mode = 'ultra';
      else if (arg === 'full') mode = 'full';
      else mode = getDefaultMode();

      if (mode && mode !== 'off') {
        safeWriteFlag(mode);
      }
    }

    if (promptLower.startsWith('/pechernyi')) {
      const parts = promptLower.split(/\s+/);
      const cmd = parts[0];
      if (cmd === '/pechernyi-commit') {
        safeWriteFlag('commit');
      } else if (cmd === '/pechernyi-review') {
        safeWriteFlag('review');
      } else if (cmd === '/pechernyi-compress' || cmd === '/pechernyi:pechernyi-compress') {
        safeWriteFlag('compress');
      }
    }

    if (activationRegex.test(prompt) || shortModeRegex.test(prompt)) {
      const mode = getDefaultMode();
      if (mode !== 'off') {
        safeWriteFlag(mode);
      }
    }

    // Security: readFlag enforces symlink-safe read + size cap + VALID_MODES whitelist.
    // Missing/corrupted/oversized/symlink flag → null → no untrusted bytes injected.
    const INDEPENDENT_MODES = new Set(['commit', 'review', 'compress']);
    const activeMode = readFlag();
    if (activeMode && !INDEPENDENT_MODES.has(activeMode)) {
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "UserPromptSubmit",
          additionalContext: "PECHERNYI MODE ACTIVE (" + activeMode + "). " +
            "Скидати вставні слова/люб'язності/хеджування. Фрагменти ок. " +
            "Паттерн: [що] [дія] [причина]."
        }
      }));
    }
  } catch (e) {
    // Silent fail
  }
});
