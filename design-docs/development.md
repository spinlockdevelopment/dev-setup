# Development

This page is the operator-facing how-to: what to do when you want to
add a new piece of content, validate a change before pushing, or
update a piece of content that has been installed in a consumer
project's read-only plugin cache.

The authoritative rules live in
[`CLAUDE.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/CLAUDE.md)
at the repo root; this page is a hands-on summary.

## Local layout when working in this checkout

```
dev-setup/
├── plugins/<plugin>/
│   ├── skills/<name>/
│   │   ├── SKILL.md          ← decision tree (thin)
│   │   ├── README.md         ← human overview (required)
│   │   ├── USAGE.md          ← user CLI deep-dive (when applicable)
│   │   └── scripts/          ← bash, idempotent, --verify mode
│   ├── agents/<name>.md      ← Claude subagent
│   ├── commands/<name>.md    ← Claude slash command
│   ├── commands/<name>.toml  ← Gemini slash command
│   └── hooks/
│       ├── hooks.json        ← polyglot registration
│       └── scripts/<name>.sh
├── .claude-plugin/marketplace.json   ← Claude marketplace
├── .agents/plugins/marketplace.json  ← Codex marketplace
├── claude-skills.md                  ← authoritative catalog
└── README.md                         ← human-facing landing
```

Skills, agents, and slash commands auto-load when Claude Code (and
Gemini CLI) run from this checkout — you can develop and test against
them in-place without going through `/plugin install`. Codex picks up
content via `codex plugin marketplace add /path/to/dev-setup`.

## Adding a new skill

1. Pick the right plugin:
    - `spindev-core` — lifecycle / session primitives used in >80%
      of projects.
    - `spindev-devenv` — developer-machine setup and sandboxing.
    - `spindev-deploy` — deployment-target-specific references.
    - `spindev-docs` — documentation tooling.

2. Create `plugins/<plugin>/skills/<name>/SKILL.md` with YAML
   frontmatter (`name`, `description`) and a thin body. The
   description always loads into context — keep it short but
   specific enough that the agent triggers reliably.

3. Create `plugins/<plugin>/skills/<name>/README.md` — plain-English
   overview. Required for every skill.

4. Put scripts in `plugins/<plugin>/skills/<name>/scripts/`. Numbered
   phase scripts when there's a sequence (see
   [`ubuntu-debloat/scripts/`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-devenv/skills/ubuntu-debloat/scripts)).
   Include a shared `lib.sh` if the skill is script-heavy; copy the
   logging / `--verify` pattern from
   [`ubuntu-debloat/scripts/lib.sh`](https://github.com/spinlockdevelopment/dev-setup/blob/main/plugins/spindev-devenv/skills/ubuntu-debloat/scripts/lib.sh).

5. If the skill ships a CLI the user drives directly (not just an
   agent), add a `USAGE.md` sibling — install, every command, every
   flag, troubleshooting. See
   [`hardened-shell/USAGE.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/plugins/spindev-devenv/skills/hardened-shell/USAGE.md)
   for the pattern.

6. Add an entry to
   [`claude-skills.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/claude-skills.md)
   under the right plugin section.

7. Update the plugin catalog in the root
   [`README.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/README.md).

8. Bump the plugin's `version` in both `.claude-plugin/plugin.json`
   and `.codex-plugin/plugin.json` if the change is non-trivial.

## Adding a new slash command

Drop `plugins/<plugin>/commands/<name>.md` (Claude) and
`plugins/<plugin>/commands/<name>.toml` (Gemini). Both are thin
prompt files that delegate to the same-named skill.

Claude shape:

```markdown
---
description: One-line summary of the command
---

Body that the agent receives when the user runs the command.

Arguments: $ARGUMENTS
```

Gemini shape:

```toml
description = "One-line summary"
prompt = """
Body that the agent receives when the user runs the command.

Arguments: {{args}}
"""
```

Commands ship in the same plugin folder as the skill they wrap.

## Adding a subagent (Claude only)

1. Create `plugins/<plugin>/agents/<name>.md` with frontmatter
   (`name`, `description`). Description must be specific enough that
   Claude auto-dispatches reliably.

2. The body is the agent's prompt. It runs in its own context window,
   so write it as if the dispatcher just walked into the room — list
   inputs, workflow phases, what's out of scope, the reporting
   format, and a self-improvement breadcrumb.

3. Never reference plugin-cache paths in the body. Let the agent
   discover scripts at runtime via the skill's `scripts/` directory.

4. If you also want a manual entry point, add a same-named slash
   command at `plugins/<plugin>/commands/<name>.md` that says
   "dispatch the `<name>` subagent".

5. Add the subagent to `claude-skills.md` and the plugin section in
   the root `README.md`.

[`pr-prepass.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/plugins/spindev-core/agents/pr-prepass.md)
and
[`technical-writer.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/plugins/spindev-docs/agents/technical-writer.md)
are the two existing subagent prompts to mirror.

## Adding a hook

1. Pick the right plugin (the one whose skill the hook backstops).

2. Write the script at `plugins/<plugin>/hooks/scripts/<name>.sh`:
    - `set -euo pipefail`.
    - Parse stdin JSON with `jq`.
    - Fast-fail when `tool_name` or the command pattern doesn't
      match (no-op exit `0`).
    - Block: print to stderr, `exit 2`. Allow with advisory: print
      to stderr, `exit 0`. Silent allow: `exit 0` with no stderr.

3. Register it in `plugins/<plugin>/hooks/hooks.json` with
   `"command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/<name>.sh"` (and
   the Gemini-side `${extensionPath}` equivalent for polyglot
   registrations).

4. `chmod +x` the script.

5. Add a self-test loop to the same commit — a table of `cmd →
   expected exit → expected warning` that runs inline. Keeps the
   matchers regression-tested.

6. Add a "Backstop hook" section to the partner skill's SKILL.md
   listing what the hook enforces, and a reminder to update the
   matchers when the rules change.

## Adding a new plugin

Resist this without a clear reason. Prefer adding a skill to an
existing plugin over creating a new one. When the dependency surface
is genuinely heavyweight (Python tooling, theme assets, GH Actions
templates — `spindev-docs` was the precedent), a new plugin is
warranted.

1. Create `plugins/<plugin-name>/.claude-plugin/plugin.json` with
   `name`, `version` (`0.1.0` for a new plugin), `description`, and
   `author`.

2. Create `plugins/<plugin-name>/.codex-plugin/plugin.json` with the
   same name/version and an `interface` block: `displayName`,
   `shortDescription`, `longDescription`, `developerName`,
   `category`, `capabilities`, `defaultPrompt`, distinct `brandColor`.

3. Create `plugins/<plugin-name>/gemini-extension.json` with `name`,
   `version`, `description`, `contextFileName: GEMINI.md`.

4. Create the `skills/`, `commands/`, `agents/`, `hooks/`
   subdirectories as the plugin needs them.

5. Add the plugin to `plugins[]` in
   [`.claude-plugin/marketplace.json`](https://github.com/spinlockdevelopment/dev-setup/blob/main/.claude-plugin/marketplace.json)
   with `"source": "./plugins/<plugin-name>"` and a category.

6. Add the plugin to `plugins[]` in
   [`.agents/plugins/marketplace.json`](https://github.com/spinlockdevelopment/dev-setup/blob/main/.agents/plugins/marketplace.json)
   with a local source path, a `policy` block, and a category.

7. Add a section to the plugin catalog in the root `README.md` and
   update `claude-skills.md`.

## Validation

Before committing or pushing, run the Claude validator from inside
this checkout:

```bash
claude plugin validate .
```

Or inside a session: `/plugin validate .`. The validator checks both
the marketplace manifest and every plugin's `.claude-plugin/plugin.json`.

For Codex and Gemini there is no local validator yet; the convention
is to mirror the shape of an existing plugin and verify
discoverability after a fresh install.

For shell scripts:

```bash
shellcheck -S warning plugins/*/skills/*/scripts/*.sh \
                       plugins/*/hooks/scripts/*.sh
```

## Self-update flow (and why it matters)

When a plugin installs into a consumer project, Claude Code copies
its files into a **read-only cache** at
`~/.claude/plugins/cache/<plugin>@<marketplace>/<version>/`. Edits in
that cache are wiped on the next `/plugin marketplace update` and
**never propagate back here**. So:

> When a SKILL.md tells the agent to "update this file in place" or
> "self-heal", that always means *here*, in this checkout — never in
> the plugin cache.

Concretely:

1. Locate a working clone of `spinlockdevelopment/dev-setup`. If
   you're already in a session inside this repo, use `$PWD`. If
   you're in a consuming project, clone the repo somewhere
   (typically `~/src/dev-setup`).
2. Edit `plugins/<plugin>/skills/<skill>/SKILL.md` (or the
   supporting script / asset) in that checkout.
3. Commit. In bringup mode (current — see the project-mode
   breadcrumb in `CLAUDE.md`) that's a direct commit to `main`. In
   protected mode, push a feature branch and open a PR.
4. Push. Consumers pick up the change on their next `/plugin
   marketplace update`.

If the change is non-trivial — a new feature or a behaviour change
rather than a bug fix — ask the operator before committing.

## Project mode

The repo declares its mode via a `## Project Mode` section in
`CLAUDE.md`. The current mode is **bringup**: commits go straight to
`main`, no feature branches, no PR workflow yet. Promotion to
protected mode (and removing this breadcrumb) happens when the first
feature branch + PR lands.

## Session history

Every working session ends with an entry appended to
[`SESSION-SUMMARIES.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/SESSION-SUMMARIES.md).
Read the latest entry before resuming work to avoid re-deriving
context. New entries are appended by `/end-session` (or by hand when
not invoking that skill).
