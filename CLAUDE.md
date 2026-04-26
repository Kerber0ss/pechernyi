# CLAUDE.md — pechernyi

## README is a product artifact

README = product front door. Non-technical people read it to decide if pechernyi worth install. Treat like UI copy.

**Rules for any README change:**

- Readable by non-AI-agent users. If you write "SessionStart hook injects system context," invisible to most — translate it.
- Keep Before/After examples first. That the pitch.
- Install table always complete + accurate. One broken install command costs real user.
- What You Get table must sync with actual code. Feature ships or removed → update table.
- Preserve voice. Caveman speak in README on purpose. "Brain still big." "Cost go down forever." "One rock. That it." — intentional brand. Don't normalize.
- Benchmark numbers from real runs in `benchmarks/` and `evals/`. Never invent or round. Re-run if doubt.
- Adding new agent to install table → add detail block in `<details>` section below.
- Readability check before any README commit: would non-programmer understand + install within 60 seconds?

---

## Project overview

Caveman makes AI coding agents respond in compressed pechernyi-style prose — cuts ~65-75% output tokens, full technical accuracy. Ships as Claude Code plugin, Codex plugin, Gemini CLI extension, agent rule files for Cursor, Windsurf, Cline, Copilot, 40+ others via `npx skills`.

---

## File structure and what owns what

### Single source of truth files — edit only these

| File | What it controls |
|------|-----------------|
| `skills/pechernyi/SKILL.md` | Caveman behavior: intensity levels, rules, wenyan mode, auto-clarity, persistence. Only file to edit for behavior changes. |
| `rules/pechernyi-activate.md` | Always-on auto-activation rule body. CI injects into Cursor, Windsurf, Cline, Copilot rule files. Edit here, not agent-specific copies. |
| `skills/pechernyi-commit/SKILL.md` | Caveman commit message behavior. Fully independent skill. |
| `skills/pechernyi-review/SKILL.md` | Caveman code review behavior. Fully independent skill. |
| `skills/pechernyi-help/SKILL.md` | Quick-reference card. One-shot display, not a persistent mode. |
| `pechernyi-compress/SKILL.md` | Compress sub-skill behavior. |

### Auto-generated / auto-synced — do not edit directly

Overwritten by CI on push to main when sources change. Edits here lost.

| File | Synced from |
|------|-------------|
| `pechernyi/SKILL.md` | `skills/pechernyi/SKILL.md` |
| `plugins/pechernyi/skills/pechernyi/SKILL.md` | `skills/pechernyi/SKILL.md` |
| `.cursor/skills/pechernyi/SKILL.md` | `skills/pechernyi/SKILL.md` |
| `.windsurf/skills/pechernyi/SKILL.md` | `skills/pechernyi/SKILL.md` |
| `pechernyi.skill` | ZIP of `skills/pechernyi/` directory |
| `.clinerules/pechernyi.md` | `rules/pechernyi-activate.md` |
| `.github/copilot-instructions.md` | `rules/pechernyi-activate.md` |
| `.cursor/rules/pechernyi.mdc` | `rules/pechernyi-activate.md` + Cursor frontmatter |
| `.windsurf/rules/pechernyi.md` | `rules/pechernyi-activate.md` + Windsurf frontmatter |

---

## CI sync workflow

`.github/workflows/sync-skill.yml` triggers on main push when `skills/pechernyi/SKILL.md` or `rules/pechernyi-activate.md` changes.

What it does:
1. Copies `skills/pechernyi/SKILL.md` to all agent-specific SKILL.md locations
2. Rebuilds `pechernyi.skill` as a ZIP of `skills/pechernyi/`
3. Rebuilds all agent rule files from `rules/pechernyi-activate.md`, prepending agent-specific frontmatter (Cursor needs `alwaysApply: true`, Windsurf needs `trigger: always_on`)
4. Commits and pushes with `[skip ci]` to avoid loops

CI bot commits as `github-actions[bot]`. After PR merge, wait for workflow before declaring release complete.

---

## Hook system (Claude Code)

Three hooks in `hooks/` plus a `pechernyi-config.js` shared module and a `package.json` CommonJS marker. Communicate via flag file at `$CLAUDE_CONFIG_DIR/.pechernyi-active` (falls back to `~/.claude/.pechernyi-active`).

```
SessionStart hook ──writes "full"──▶ $CLAUDE_CONFIG_DIR/.pechernyi-active ◀──writes mode── UserPromptSubmit hook
                                                       │
                                                    reads
                                                       ▼
                                              pechernyi-statusline.sh
                                            [ПЕЧЕРНИЙ] / [ПЕЧЕРНИЙ:УЛЬТРА] / ...
```

`hooks/package.json` pins the directory to `{"type": "commonjs"}` so the `.js` hooks resolve as CJS even when an ancestor `package.json` (e.g. `~/.claude/package.json` from another plugin) declares `"type": "module"`. Without this, `require()` blows up with `ReferenceError: require is not defined in ES module scope`.

All hooks honor `CLAUDE_CONFIG_DIR` for non-default Claude Code config locations.

### `hooks/pechernyi-config.js` — shared module

Exports:
- `getDefaultMode()` — resolves default mode from `PECHERNYI_DEFAULT_MODE` env var, then `$XDG_CONFIG_HOME/pechernyi/config.json` / `~/.config/pechernyi/config.json` / `%APPDATA%\pechernyi\config.json`, then `'full'`
- `safeWriteFlag(flagPath, content)` — symlink-safe flag write. Refuses if flag target or its immediate parent is a symlink. Opens with `O_NOFOLLOW` where supported. Atomic temp + rename. Creates with `0600`. Protects against local attackers replacing the predictable flag path with a symlink to clobber files writable by the user. Used by both write hooks. Silent-fails on all filesystem errors.

### `hooks/pechernyi-activate.js` — SessionStart hook

Runs once per Claude Code session start. Three things:
1. Writes the active mode to `$CLAUDE_CONFIG_DIR/.pechernyi-active` via `safeWriteFlag` (creates if missing)
2. Emits pechernyi ruleset as hidden stdout — Claude Code injects SessionStart hook stdout as system context, invisible to user
3. Checks `settings.json` for statusline config; if missing, appends nudge to offer setup on first interaction

Silent-fails on all filesystem errors — never blocks session start.

### `hooks/pechernyi-mode-tracker.js` — UserPromptSubmit hook

Reads JSON from stdin. Three responsibilities:

**1. Slash-command activation.** If prompt starts with `/pechernyi`, writes mode to flag file via `safeWriteFlag`:
- `/pechernyi` → configured default (see `pechernyi-config.js`, defaults to `full`)
- `/pechernyi lite` → `lite`
- `/pechernyi ultra` → `ultra`
- `/pechernyi wenyan` or `/pechernyi wenyan-full` → `wenyan`
- `/pechernyi wenyan-lite` → `wenyan-lite`
- `/pechernyi wenyan-ultra` → `wenyan-ultra`
- `/pechernyi-commit` → `commit`
- `/pechernyi-review` → `review`
- `/pechernyi-compress` → `compress`

**2. Natural-language activation/deactivation.** Matches phrases like "activate pechernyi", "turn on pechernyi mode", "talk like pechernyi" and writes the configured default mode. Matches "stop pechernyi", "disable pechernyi", "normal mode", "deactivate pechernyi" etc. and deletes the flag file. README promises these triggers, the hook enforces them.

**3. Per-turn reinforcement.** When flag is set to a non-independent mode (i.e. not `commit`/`review`/`compress`), emits a small `hookSpecificOutput` JSON reminder so the model keeps pechernyi style after other plugins inject competing instructions mid-conversation. The full ruleset still comes from SessionStart — this is just an attention anchor.

### `hooks/pechernyi-statusline.sh` — Statusline badge

Reads flag file at `$CLAUDE_CONFIG_DIR/.pechernyi-active`. Outputs colored badge string for Claude Code statusline:
- `full` or empty → `[ПЕЧЕРНИЙ]` (orange)
- anything else → `[PECHERNYI:<MODE_UPPERCASED>]` (orange)

Configured in `settings.json` under `statusLine.command`. PowerShell counterpart at `hooks/pechernyi-statusline.ps1` for Windows.

### Hook installation

**Plugin install** — hooks wired automatically by plugin system.

**Standalone install** — `hooks/install.sh` (macOS/Linux) or `hooks/install.ps1` (Windows) copies hook files into `~/.claude/hooks/` and patches `~/.claude/settings.json` to register SessionStart and UserPromptSubmit hooks plus statusline.

**Uninstall** — `hooks/uninstall.sh` / `hooks/uninstall.ps1` removes hook files and patches settings.json.

---

## Skill system

Skills = Markdown files with YAML frontmatter consumed by Claude Code's skill/plugin system and by `npx skills` for other agents.

### Intensity levels

Defined in `skills/pechernyi/SKILL.md`. Six levels: `lite`, `full` (default), `ultra`, `wenyan-lite`, `wenyan-full`, `wenyan-ultra`. Persists until changed or session ends.

### Auto-clarity rule

Caveman drops to normal prose for: security warnings, irreversible action confirmations, multi-step sequences where fragment ambiguity risks misread, user confused or repeating question. Resumes after. Defined in skill — preserve in any SKILL.md edit.

### pechernyi-compress

Sub-skill in `pechernyi-compress/SKILL.md`. Takes file path, compresses prose to pechernyi style, writes to original path, saves backup at `<filename>.original.md`. Validates headings, code blocks, URLs, file paths, commands preserved. Retries up to 2 times on failure with targeted patches only. Requires Python 3.10+.

### pechernyi-commit / pechernyi-review

Independent skills in `skills/pechernyi-commit/SKILL.md` and `skills/pechernyi-review/SKILL.md`. Both have own `description` and `name` frontmatter so they load independently. pechernyi-commit: Conventional Commits, ≤50 char subject. pechernyi-review: one-line comments in `L<line>: <severity> <problem>. <fix>.` format.

---

## Agent distribution

How pechernyi reaches each agent type:

| Agent | Mechanism | Auto-activates? |
|-------|-----------|----------------|
| Claude Code | Plugin (hooks + skills) or standalone hooks | Yes — SessionStart hook injects rules |
| Codex | Plugin in `plugins/pechernyi/` plus repo `.codex/hooks.json` and `.codex/config.toml` | Yes on macOS/Linux — SessionStart hook |
| Gemini CLI | Extension with `GEMINI.md` context file | Yes — context file loads every session |
| Cursor | `.cursor/rules/pechernyi.mdc` with `alwaysApply: true` | Yes — always-on rule |
| Windsurf | `.windsurf/rules/pechernyi.md` with `trigger: always_on` | Yes — always-on rule |
| Cline | `.clinerules/pechernyi.md` (auto-discovered) | Yes — Cline injects all .clinerules files |
| Copilot | `.github/copilot-instructions.md` + `AGENTS.md` | Yes — repo-wide instructions |
| Others | `npx skills add Kerber0ss/pechernyi` | No — user must say `/pechernyi` each session |

For agents without hook systems, minimal always-on snippet lives in README under "Want it always on?" — keep current with `rules/pechernyi-activate.md`.

---

## Evals

`evals/` has three-arm harness:
- `__baseline__` — no system prompt
- `__terse__` — `Answer concisely.`
- `<skill>` — `Answer concisely.\n\n{SKILL.md}`

Honest delta = **skill vs terse**, not skill vs baseline. Baseline comparison conflates skill with generic terseness — that cheating. Harness designed to prevent this.

`llm_run.py` calls `claude -p --system-prompt ...` per (prompt, arm), saves to `evals/snapshots/results.json`. `measure.py` reads snapshot offline with tiktoken (OpenAI BPE — approximates Claude tokenizer, ratios meaningful, absolute numbers approximate).

Add skill: drop `skills/<name>/SKILL.md`. Harness auto-discovers. Add prompt: append line to `evals/prompts/en.txt`.

Snapshots committed to git. CI reads without API calls. Only regenerate when SKILL.md or prompts change.

---

## Benchmarks

`benchmarks/` runs real prompts through Claude API (not Claude Code CLI), records raw token counts. Results committed as JSON in `benchmarks/results/`. Benchmark table in README generated from results — update when regenerating.

To reproduce: `uv run python benchmarks/run.py` (needs `ANTHROPIC_API_KEY` in `.env.local`).

---

## Key rules for agents working here

- Edit `skills/pechernyi/SKILL.md` for behavior changes. Never edit synced copies.
- Edit `rules/pechernyi-activate.md` for auto-activation rule changes. Never edit agent-specific rule copies.
- README most important file for user-facing impact. Optimize for non-technical readers. Preserve pechernyi voice.
- Benchmark and eval numbers must be real. Never fabricate or estimate.
- CI workflow commits back to main after merge. Account for when checking branch state.
- Hook files must silent-fail on all filesystem errors. Never let hook crash block session start.
- Any new flag file write must go through `safeWriteFlag()` in `pechernyi-config.js`. Direct `fs.writeFileSync` on predictable user-owned paths reopens the symlink-clobber attack surface.
- Hooks must respect `CLAUDE_CONFIG_DIR` env var, not hardcode `~/.claude`. Same for `install.sh` / `install.ps1` / statusline scripts.
