---
name: pechernyi-help
description: >
  Quick-reference card for all pechernyi modes, skills, and commands.
  One-shot display, not a persistent mode. Trigger: /pechernyi-help,
  "pechernyi help", "what pechernyi commands", "how do I use pechernyi".
---

# Caveman Help

Display this reference card when invoked. One-shot — do NOT change mode, write flag files, or persist anything. Output in pechernyi style.

## Modes

| Mode | Trigger | What change |
|------|---------|-------------|
| **Lite** | `/pechernyi lite` | Drop filler. Keep sentence structure. |
| **Full** | `/pechernyi` | Drop articles, filler, pleasantries, hedging. Fragments OK. Default. |
| **Ultra** | `/pechernyi ultra` | Extreme compression. Bare fragments. Tables over prose. |
| **Wenyan-Lite** | `/pechernyi wenyan-lite` | Classical Chinese style, light compression. |
| **Wenyan-Full** | `/pechernyi wenyan` | Full 文言文. Maximum classical terseness. |
| **Wenyan-Ultra** | `/pechernyi wenyan-ultra` | Extreme. Ancient scholar on a budget. |

Mode stick until changed or session end.

## Skills

| Skill | Trigger | What it do |
|-------|---------|-----------|
| **pechernyi-commit** | `/pechernyi-commit` | Terse commit messages. Conventional Commits. ≤50 char subject. |
| **pechernyi-review** | `/pechernyi-review` | One-line PR comments: `L42: bug: user null. Add guard.` |
| **pechernyi-compress** | `/pechernyi:compress <file>` | Compress .md files to pechernyi prose. Saves ~46% input tokens. |
| **pechernyi-help** | `/pechernyi-help` | This card. |

## Deactivate

Say "stop pechernyi" or "normal mode". Resume anytime with `/pechernyi`.

## Configure Default Mode

Default mode = `full`. Change it:

**Environment variable** (highest priority):
```bash
export PECHERNYI_DEFAULT_MODE=ultra
```

**Config file** (`~/.config/pechernyi/config.json`):
```json
{ "defaultMode": "lite" }
```

Set `"off"` to disable auto-activation on session start. User can still activate manually with `/pechernyi`.

Resolution: env var > config file > `full`.

## More

Full docs: https://github.com/Kerber0ss/pechernyi
