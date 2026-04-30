# Glossary

Terms this site uses consistently. The three target harnesses (Claude
Code, Codex CLI, Gemini CLI) do not all use these terms the same way
— the definitions below are the ones that hold inside this repo.

### Bringup mode

The project's current mode, declared by a `## Project Mode` section
in `CLAUDE.md`. Commits go straight to `main`; no feature branches,
no PR workflow yet. Contrast with **protected mode**, where
mandatory PRs and squash-merge are enforced. This repo is currently
in bringup mode; promotion happens when the first feature branch +
PR lands.

### Harness

A CLI agent that loads plugins from this marketplace. The three
harnesses targeted are **Claude Code**, **Codex CLI** (OpenAI), and
**Gemini CLI** (Google). Each harness loads a different subset of
the plugin tree: Claude reads `SKILL.md` + `agents/` + `commands/*.md`
+ `hooks/`; Codex reads `SKILL.md` only; Gemini reads `SKILL.md` +
`commands/*.toml` + the polyglot hook entries.

### Hook

A small shell script that intercepts a tool call before it executes.
Hooks live at `plugins/<plugin>/hooks/scripts/<name>.sh` and are
registered in `plugins/<plugin>/hooks/hooks.json`. They parse the
tool call's stdin JSON with `jq`, then either allow it (`exit 0`),
allow with an advisory message (`exit 0` plus stderr), or block it
(`exit 2` plus stderr). On Claude Code, hooks fire on the
`PreToolUse` event; on Gemini CLI, the equivalent event is
`BeforeTool`. Polyglot registrations target both.

### Marketplace

A JSON manifest at the repo root that lists the plugins available
for install. This repo serves two: `.claude-plugin/marketplace.json`
for Claude Code and `.agents/plugins/marketplace.json` for Codex
CLI. Gemini CLI does not use a marketplace — its plugins are
installed individually as **extensions**.

### Plugin

A self-contained unit of distribution. Each plugin lives in its own
`plugins/<name>/` directory and ships per-harness manifests
(`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
`gemini-extension.json`) that point at the same shared `skills/`
tree. The four plugins this repo publishes are `spindev-core`,
`spindev-devenv`, `spindev-deploy`, and `spindev-docs`.

### Plugin cache (read-only)

The directory Claude Code copies a plugin into when it installs:
`~/.claude/plugins/cache/<plugin>@<marketplace>/<version>/`. Edits
inside this directory are **wiped on the next `/plugin marketplace
update`** and never flow back to this checkout. So when a SKILL.md
says "self-heal" or "update in place", it always means: edit this
checkout, commit, push.

### Self-improvement / self-healing

The mechanism by which a skill detects drift in its own pinned
upstream versions or rules and updates them in place. Skills that
pin specific package versions (e.g. `restic 0.18.1`,
`Forgejo v15.0.1`) include explicit instructions for the agent to
detect drift during execution and edit the pinned values at the
authoritative location in this checkout — never in the plugin
cache.

### Skill

The cross-platform unit of agent guidance. Each skill lives at
`plugins/<plugin>/skills/<name>/`, with a thin `SKILL.md` (decision
tree only — when to do what), a `README.md` (human-facing
overview), an optional `USAGE.md` (user-driven CLI deep-dive when
the skill ships a runtime users drive directly), and a `scripts/`
folder where the heavy lifting lives. SKILL.md is the only artifact
all three harnesses read; everything else (slash commands,
subagents, hooks) is harness-specific. Frontmatter descriptions
always load into context, so they need to be tight but specific
enough to trigger reliably.

### Slash command

A user-facing entry point that dispatches a skill or subagent.
Claude Code reads `commands/<name>.md` (frontmatter `description` +
thin body); Gemini CLI reads `commands/<name>.toml` (`description` +
`prompt` keys). Codex CLI does not load slash commands. Commands
ship in the same plugin folder as the skill or subagent they wrap.

### Subagent

A Claude-only secondary agent invoked from the primary agent's
context. Subagents live at `plugins/<plugin>/agents/<name>.md` with
YAML frontmatter (`name`, `description`) and a procedural prompt
body. They run in their own context window, so the body is written
as if the dispatcher just walked into the room: inputs, workflow
phases, what's out of scope, reporting format, self-improvement
breadcrumb. Codex and Gemini do not have a subagent concept — for
them, the same workflow runs inside the SKILL.md decision tree
directly.

### `--verify` mode

The read-only health-check path supported by every script-heavy
skill. Instead of installing or modifying, `--verify` reports what
is missing or drifted and exits non-zero if anything would need a
write. Lets operators confirm the system state without taking any
action; lets `end-session` validate before push.
