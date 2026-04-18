# dev-setup — Claude Code plugin marketplace

This repo is a **Claude Code plugin marketplace** publishing three
plugins' worth of custom skills, slash commands, and companion scripts
for setting up and maintaining developer environments. It's consumed
two ways:

1. **Active use inside this repo.** Skills under `plugins/*/skills/`
   and slash commands under `plugins/*/commands/` auto-load when Claude
   Code runs from this project — nothing to install.
2. **Distribution to other projects.** Each project adds this
   marketplace to its `.claude/settings.json`
   (`extraKnownMarketplaces`) and enables whichever plugins it wants
   (`enabledPlugins`). Works on Claude Code desktop, CLI, and Web. See
   [`README.md`](./README.md) for the settings snippet.

The old symlink / `~/.claude/skills/` junction model is gone. Don't
recreate it — it breaks on Claude Code Web.

## Index

The authoritative catalog of skills lives in
[`claude-skills.md`](./claude-skills.md). Read that before adding a
skill, editing an existing one, or telling the user what's available.

Migration history:
- [`MIGRATION_INVENTORY.md`](./MIGRATION_INVENTORY.md) — skills inventory before the marketplace port
- [`MIGRATION_PLAN.md`](./MIGRATION_PLAN.md) — grouping rationale

## Plugin layout

```
.claude-plugin/marketplace.json     ← registry listing all plugins
plugins/
  spindev-core/
    .claude-plugin/plugin.json
    commands/<name>.md              ← slash-command wrappers
    skills/<name>/SKILL.md          ← skills
  spindev-devenv/
    .claude-plugin/plugin.json
    skills/<name>/
  spindev-deploy/
    .claude-plugin/plugin.json
    skills/<name>/
```

Rules:
- Plugin folder name matches `plugin.json` `name` exactly.
- Skills live at `plugins/<plugin>/skills/<skill>/SKILL.md` — no
  deeper nesting.
- Slash commands live at `plugins/<plugin>/commands/<name>.md`, in the
  same plugin as the skill they wrap.
- Every plugin in `plugins/` is listed in
  `.claude-plugin/marketplace.json`. Every listed plugin has a
  `.claude-plugin/plugin.json`.

## Conventions for skills in this repo

- **Thin `SKILL.md`.** Decision tree for Claude, not an instruction
  manual. The body tells Claude *when* to do what; scripts know *how*.
- **`README.md` per skill (required).** Every skill has a sibling
  `README.md` with a plain-English overview: what it is, why it
  exists, what it does. Human-facing landing page.
- **`USAGE.md` per skill (optional).** If the skill ships a CLI or
  runtime users drive directly (not just Claude), add a `USAGE.md`
  alongside `README.md` for the deep how-to — install, every command,
  every flag, troubleshooting, customization. See
  `plugins/spindev-devenv/skills/hardened-shell/` for the pattern.
- **Tight frontmatter descriptions.** Descriptions always load into
  context; keep them short but specific enough to trigger reliably.
- **Heavy lifting in `scripts/`.** Each skill ships idempotent bash
  scripts next to its `SKILL.md`.
- **Idempotent + `--verify` mode.** Scripts should be safe to re-run
  and support a read-only verification path.
- **Self-healing.** Skills that pin upstream versions (package URLs,
  LTS releases) include instructions for Claude to detect drift and
  update pinned values in place.
- **LTS / GA stable only.** Skills target the latest LTS or public-GA
  release, not bleeding edge.

## Adding a new skill

1. Pick the right plugin. `spindev-core` for lifecycle/session
   primitives used in >80% of projects. `spindev-devenv` for
   developer-machine setup and sandboxing. `spindev-deploy` for
   deployment-target-specific references.
2. Create `plugins/<plugin>/skills/<name>/SKILL.md` with YAML
   frontmatter (`name`, `description`) and a thin body.
3. Create `plugins/<plugin>/skills/<name>/README.md` — plain-English
   overview.
4. Put scripts in `plugins/<plugin>/skills/<name>/scripts/`. Include
   a shared `lib.sh` if the skill is script-heavy (see
   `ubuntu-debloat`).
5. If the skill ships a user-driven CLI, add a `USAGE.md` sibling —
   see `hardened-shell/`.
6. Add an entry to [`claude-skills.md`](./claude-skills.md) under
   the right plugin section.
7. Update the plugin catalog in the root [`README.md`](./README.md).

## Adding a new slash command

Drop `plugins/<plugin>/commands/<name>.md` — thin prompt file with
`description` frontmatter, delegating to the same-named skill. Commands
ship in the same plugin as the skill they wrap.

## Adding a new plugin

1. Create `plugins/<plugin-name>/.claude-plugin/plugin.json` with
   `name`, `version` (`0.1.0` for a new plugin), `description`, and
   `author`.
2. Create `plugins/<plugin-name>/skills/` (and `commands/` if needed).
3. Add the plugin to `plugins[]` in
   [`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json)
   with `"source": "./plugins/<plugin-name>"`.
4. Add a section to the plugin catalog in the root
   [`README.md`](./README.md).

Resist splitting existing plugins without a clear reason — prefer
adding a skill to an existing plugin over creating a new one.

## Validating before pushing

```shell
claude plugin validate .
```

Or inside a session: `/plugin validate .`.

## Project Mode

Bringup. Commits go straight to `main`, no feature branches, no PR
workflow yet. Promote to protected mode (and remove this breadcrumb)
when the first feature branch + PR lands.

## Session history

See [SESSION-SUMMARIES.md](SESSION-SUMMARIES.md).
