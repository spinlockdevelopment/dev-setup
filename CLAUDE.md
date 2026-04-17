# setup — reusable dev environment tools & agentic workflow skills

This repo is a **curated cache of custom Claude Code skills, slash
commands, and companion scripts** for setting up and maintaining developer
environments. It's meant to be consumed two ways:

1. **Active use inside this repo.** Skills under `.claude/skills/` and
   slash commands under `.claude/commands/` auto-load when Claude Code
   runs from this project — nothing to install.
2. **Reuse in other projects.** Symlink individual skills (or the whole
   `.claude/skills/` tree) into another project's `.claude/skills/`, or
   into `~/.claude/skills/` for user-wide availability. The whole
   `.claude/commands/` directory is junctioned to `~/.claude/commands/`
   so every slash command here is also a user-level slash command —
   adding a file under `.claude/commands/` here immediately makes it
   available in every project.

## Index

The authoritative list of skills lives in [`claude-skills.md`](./claude-skills.md).
Read that before adding a skill, editing an existing one, or telling the user
what's available.

For a human-facing overview (what's in this repo, per-skill install
intent, symlink instructions) see [`README.md`](./README.md).

## Conventions for skills in this repo

- **Thin SKILL.md.** Treat it as a decision tree for Claude, not an
  instruction manual. The body tells Claude *when* to do what; the scripts
  know *how*.
- **`README.md` per skill (required).** Every skill has a sibling `README.md`
  that gives a plain-English overview: what it is, why it exists, what it
  does, and an **Installation intent** section (user-level, project-level,
  or both, with the exact symlink command). This is the human-facing
  landing page.
- **`USAGE.md` per skill (optional).** If the skill ships a CLI or runtime
  that users drive directly (not just Claude), add a `USAGE.md` alongside
  `README.md` for the deep how-to — install flow, every command, every
  flag, troubleshooting, customization. See `hardened-shell/` for the
  pattern. Skills without a user-facing CLI don't need `USAGE.md`; the
  `README.md` is enough.
- **Tight frontmatter descriptions.** Descriptions are always in context, so
  keep them short while still specific enough to trigger reliably.
- **Heavy lifting in `scripts/`.** Each skill ships idempotent bash scripts
  next to its SKILL.md.
- **Idempotent + `--verify` mode.** Every script should be safe to re-run and
  support a read-only verification path.
- **Self-healing.** Skills that pin upstream versions (package URLs, LTS
  releases) include instructions for Claude to detect drift and update the
  pinned values in place. See the self-healing section in each skill's
  SKILL.md.
- **LTS / GA stable only.** Skills target the latest LTS or public-GA
  release, not bleeding edge.

## Adding a new skill

1. Create `.claude/skills/<name>/SKILL.md` with YAML frontmatter (`name`,
   `description`) and a thin body.
2. Create `.claude/skills/<name>/README.md` — plain-English overview with
   a clear **Installation intent** section (user-level, project-level, or
   both, with the exact symlink command).
3. Put scripts in `.claude/skills/<name>/scripts/`.
4. If the skill is shell-script-heavy, include a `scripts/lib.sh` for shared
   logging and idempotency helpers (follow the pattern in `ubuntu-debloat`).
5. If the skill ships a CLI or runtime the user drives directly, add a
   `USAGE.md` sibling to `SKILL.md` with install steps, examples, and
   troubleshooting. See `hardened-shell/` for the pattern.
6. Add an entry to `claude-skills.md` with a one-line summary, entry
   point, and installation intent.
7. Add the skill to the **Skills at a glance** table in the root
   `README.md`.

## Slash commands

`.claude/commands/*.md` files are thin slash-command wrappers. Each one
is a prompt file with `description` frontmatter and a short body that
delegates to the same-named skill (passing `$ARGUMENTS` through). The
whole directory is junctioned into `~/.claude/commands/` so commands
here are available in every project without per-project install.

Add a new command by dropping a `<name>.md` file into
`.claude/commands/`. Keep it a few lines at most — the heavy lifting
lives in the skill the command invokes.

## Project Mode

Bringup. Commits go straight to `main`, no feature branches, no PR
workflow yet. Promote to protected mode (and remove this breadcrumb)
when the first feature branch + PR lands.

## Session history

See [SESSION-SUMMARIES.md](SESSION-SUMMARIES.md).
