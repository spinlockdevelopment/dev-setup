# Architecture

The repository is a single Git tree that simultaneously plays three
roles: a Codex CLI plugin marketplace (rooted at
[`.agents/plugins/marketplace.json`](https://github.com/spinlockdevelopment/dev-setup/blob/main/.agents/plugins/marketplace.json)),
a Claude Code plugin marketplace (rooted at
[`.claude-plugin/marketplace.json`](https://github.com/spinlockdevelopment/dev-setup/blob/main/.claude-plugin/marketplace.json)),
and a collection of Gemini CLI extensions (one per plugin folder via
`gemini-extension.json`). All three roles point at the same four
plugin directories under `plugins/`, so a change to a skill or an
agent prompt is automatically visible to all three harnesses.

## Top-level layout

```
dev-setup/
├── .agents/plugins/marketplace.json     ← Codex CLI marketplace
├── .claude-plugin/marketplace.json      ← Claude Code marketplace
├── plugins/
│   ├── spindev-core/                    ← lifecycle / session primitives
│   ├── spindev-devenv/                  ← developer-machine setup
│   ├── spindev-deploy/                  ← deployment-target references
│   └── spindev-docs/                    ← documentation generation
├── claude-skills.md                     ← authoritative skill catalog
├── README.md                            ← human-facing landing page
├── CLAUDE.md                            ← agent-facing project rules
├── GEMINI.md                            ← Gemini-specific context
├── AGENTS.md                            ← Codex-specific context
└── SESSION-SUMMARIES.md                 ← append-only work log
```

The four plugins are organized along orthogonal axes. They are
intentionally independent — a project that only wants `/end-session`
can install just `spindev-core` and pay nothing for the Docker image
or restic chain that the other plugins reference.

| Plugin | Axis | Install on |
|---|---|---|
| `spindev-core` | Workflow | every project |
| `spindev-devenv` | Developer-machine setup | the box itself, once |
| `spindev-deploy` | Deployment target | projects deploying to one of its platforms |
| `spindev-docs` | Documentation generation | projects that publish a design doc |

## Plugin internal layout

Every plugin follows the same structure. The plugin folder name
matches the `name` field in its manifests exactly.

```
plugins/<plugin>/
├── .codex-plugin/plugin.json   ← Codex manifest (with `interface` block)
├── .claude-plugin/plugin.json  ← Claude manifest
├── gemini-extension.json       ← Gemini manifest
├── commands/<name>.md          ← Claude slash commands
├── commands/<name>.toml        ← Gemini slash commands
├── skills/<name>/SKILL.md      ← shared skills (cross-platform)
├── skills/<name>/README.md     ← human-facing overview (required)
├── skills/<name>/USAGE.md      ← user-driven CLI deep-dive (when applicable)
├── skills/<name>/scripts/      ← idempotent bash, --verify mode
├── agents/<name>.md            ← Claude subagents (Claude-only)
└── hooks/hooks.json            ← polyglot hook registrations
    hooks/scripts/<name>.sh
```

The discoverability story differs by harness:

- **Claude Code** loads `SKILL.md` files automatically, plus `agents/`,
  `commands/`, and `hooks/`.
- **Codex CLI** loads `SKILL.md` only — no slash commands, no
  subagents, no hooks at the agent layer.
- **Gemini CLI** loads `SKILL.md` and `commands/<name>.toml` plus the
  polyglot hook entries that target Gemini's `BeforeTool` event.

All three are driven from the same `skills/` directory. Subagents are
a Claude-only bonus that wraps the same scripts; the SKILL.md is the
cross-platform anchor and contains the decision tree the agent
follows.

## Conventions every skill follows

The conventions in [`CLAUDE.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/CLAUDE.md)
are enforced by reading habit and validation, not lint:

- **Thin SKILL.md.** Decision tree only — when to do what. Heavy
  lifting lives in `scripts/`.
- **README.md per skill.** Plain-English overview is required; this
  is the human-facing landing page.
- **USAGE.md when applicable.** Skills that ship a user-driven CLI
  (e.g. `hardened-shell`'s `hshell`) include a deeper how-to next to
  the README — install, every command, every flag, troubleshooting.
- **Heavy lifting in `scripts/`.** Bash, idempotent, fast-fail on
  non-matching input, exit `0` to allow / `2` to block (for hooks),
  with a `--verify` read-only mode where applicable.
- **Self-healing.** Skills that pin upstream versions detect drift
  during execution and update the pinned values in place at the
  authoritative copy in this repo.
- **LTS / public-GA only.** No bleeding edge. Pinned dates are
  written in code (`# pinned 2026-04-29`) and bumped together.

## Distribution

The same checkout serves three install paths.

### Codex CLI

```bash
codex plugin marketplace add /path/to/dev-setup
```

The marketplace at `.agents/plugins/marketplace.json` lists every
plugin with a local source path and a policy block.

### Claude Code

A consumer project either points at the GitHub repo directly via
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "spinlockdevelopment": {
      "source": { "source": "github", "repo": "spinlockdevelopment/dev-setup" }
    }
  },
  "enabledPlugins": {
    "spindev-core@spinlockdevelopment": true,
    "spindev-devenv@spinlockdevelopment": true,
    "spindev-deploy@spinlockdevelopment": true,
    "spindev-docs@spinlockdevelopment": true
  }
}
```

…or a session-level `/plugin marketplace add spinlockdevelopment/dev-setup`.

When a plugin installs, Claude Code copies its files into a
**read-only cache** at
`~/.claude/plugins/cache/<plugin>@<marketplace>/<version>/`. Edits
inside that cache are wiped on the next `/plugin marketplace update`
and never propagate back. A skill telling Claude to "self-heal" or
"update in place" therefore means: edit this checkout, commit, push.

### Gemini CLI

Each plugin folder is also a Gemini CLI extension:

```bash
gemini extensions install ./plugins/spindev-core
gemini extensions install ./plugins/spindev-devenv
gemini extensions install ./plugins/spindev-deploy
gemini extensions install ./plugins/spindev-docs
```

The polyglot hook registrations in `plugins/spindev-core/hooks/hooks.json`
and `plugins/spindev-deploy/hooks/hooks.json` use `${extensionPath}`
for Gemini-side script resolution and `${CLAUDE_PLUGIN_ROOT}` for
Claude-side resolution, so the same hook script is invoked from both
harnesses without duplication.

## Validation

Before pushing, every change is checked with the Claude validator
from inside this checkout:

```bash
claude plugin validate .
```

This validates the marketplace manifest and every plugin's
`.claude-plugin/plugin.json`. Codex and Gemini do not (yet) ship a
local validator; for those manifests the convention is to mirror the
shape of an existing plugin and verify discoverability after a fresh
install.
