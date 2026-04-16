# setup — reusable dev environment tools & agentic workflow skills

This repo is a **curated cache of custom Claude Code skills + companion
scripts** for setting up and maintaining developer environments. It's meant
to be consumed two ways:

1. **Active use inside this repo.** Skills under `.claude/skills/` auto-load
   when Claude Code runs from this project — nothing to install.
2. **Reuse in other projects.** Symlink individual skills (or the whole
   `.claude/skills/` tree) into another project's `.claude/skills/`, or into
   `~/.claude/skills/` for user-wide availability.

## Index

The authoritative list of skills lives in [`claude-skills.md`](./claude-skills.md).
Read that before adding a skill, editing an existing one, or telling the user
what's available.

## Conventions for skills in this repo

- **Thin SKILL.md.** Treat it as a decision tree for Claude, not an
  instruction manual. The body tells Claude *when* to do what; the scripts
  know *how*. For human-facing "how do I use this" docs, add a sibling
  `USAGE.md` next to `SKILL.md` (see `hardened-shell/` for an example).
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
2. Put scripts in `.claude/skills/<name>/scripts/`.
3. Add an entry to `claude-skills.md` with a one-line summary + entry point.
4. If the skill is shell-script-heavy, include a `scripts/lib.sh` for shared
   logging and idempotency helpers (follow the pattern in `ubuntu-debloat`).
5. If the skill is user-facing (has a CLI or runtime the user drives
   directly), add a `USAGE.md` sibling to `SKILL.md` with install steps,
   examples, and troubleshooting.

## Project Mode

Bringup. Commits go straight to `main`, no feature branches, no PR
workflow yet. Promote to protected mode (and remove this breadcrumb)
when the first feature branch + PR lands.

## Session history

See [SESSION-SUMMARIES.md](SESSION-SUMMARIES.md).
