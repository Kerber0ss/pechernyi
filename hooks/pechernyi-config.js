'use strict';
const path = require('path');
const os = require('os');
const fs = require('fs');

const VALID_MODES = ['off', 'lite', 'full', 'ultra', 'commit', 'review', 'compress'];

function getFlagPath() {
  return path.join(
    process.env.CLAUDE_CONFIG_DIR || (os.homedir() + '/.claude'),
    '.pechernyi-active'
  );
}

function getDefaultMode() {
  const env = process.env.PECHERNYI_DEFAULT_MODE;
  return (env && VALID_MODES.includes(env)) ? env : 'off';
}

function safeWriteFlag(mode) {
  if (!VALID_MODES.includes(mode)) return;
  try {
    const flagPath = getFlagPath();
    fs.mkdirSync(path.dirname(flagPath), { recursive: true });
    fs.writeFileSync(flagPath, mode, 'utf8');
  } catch (_) { /* silent */ }
}

function readFlag() {
  try {
    const flagPath = getFlagPath();
    const buf = Buffer.alloc(64);
    const fd = fs.openSync(flagPath, 'r');
    const bytesRead = fs.readSync(fd, buf, 0, 64, 0);
    fs.closeSync(fd);
    const content = buf.slice(0, bytesRead).toString('utf8');
    const sanitized = content.replace(/[^a-z0-9-]/g, '').trim();
    return VALID_MODES.includes(sanitized) ? sanitized : null;
  } catch (_) {
    return null;
  }
}

module.exports = { VALID_MODES, getDefaultMode, safeWriteFlag, readFlag };
