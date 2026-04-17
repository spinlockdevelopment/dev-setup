# dev-setup

A curated cache of custom **Claude Code skills** plus companion scripts
for setting up and maintaining developer environments.

This repo is the canonical source. Skills here are meant to be
**symlinked out** of this repo to wherever they need to run (typically
`~/.claude/skills/` for user-wide availability). That way every
environment points at one checkout and `git pull` here propagates
updates to every place the skill is installed.

## What's in here

| Path | Purpose |
|---|---|
| [`.claude/skills/`](./.claude/skills/) | The skills themselves. Each skill is a directory with `SKILL.md`, `README.md`, and usually `scripts/`. |
| [`.claude/commands/`](./.claude/commands/) | Thin slash-command wrappers (`<name>.md`) that delegate to same-named skills. Directory is junctioned to `~/.claude/commands/` so every file here is also a user-level slash command. |
| [`claude-skills.md`](./claude-skills.md) | Authoritative index of every skill in this repo — read this before adding, editing, or recommending a skill. |
| [`CLAUDE.md`](./CLAUDE.md) | Claude-facing guidance for working inside this repo (conventions, project mode, history pointer). |
| [`SESSION-SUMMARIES.md`](./SESSION-SUMMARIES.md) | Append-only log of what each working session accomplished. |
| [`docs/`](./docs/) | Plans and longer-form docs (currently just `docs/superpowers/`). |

## Skills at a glance

Most skills here are **user-level**: intended to be symlinked (junctioned
on Windows) into `~/.claude/skills/` so Claude reaches them in any
project. `sprites-dev` is **project-level** — junction it into the
`.claude/skills/` of whichever project deploys to sprites.dev.

| Skill | What it's for | Install target |
|---|---|---|
| [`end-session`](./.claude/skills/end-session/) | Cleanly wraps up a working session before `/clear` — syncs docs, memory, TODOs, runs quality gates, opens a PR with auto-merge when work is done. | `~/.claude/skills/end-session/` |
| [`hardened-shell`](./.claude/skills/hardened-shell/) | Ships `hshell`, a launcher that runs Claude in `--dangerously-skip-permissions` mode inside a locked-down Docker sandbox. | `~/.claude/skills/hardened-shell/` + `hshell` CLI at `~/.local/bin/hshell` |
| [`review-plan`](./.claude/skills/review-plan/) | Pre-implementation hardening pass on superpowers plans — cross-model adversarial review plus checkpoint-block injection at subsystem seams. | `~/.claude/skills/review-plan/` |
| [`sprites-dev`](./.claude/skills/sprites-dev/) | Correct-usage reference for the `sprite` CLI and sprites.dev API on Windows/Git Bash — avoids path mangling, flag-ordering bugs, and large-file upload failures. | `<project>/.claude/skills/sprites-dev/` (project-level) |
| [`ubuntu-debloat`](./.claude/skills/ubuntu-debloat/) | Debloats fresh Ubuntu desktop installs and sets them up for dev work. Idempotent; supports `--verify`; self-heals on upstream drift. | `~/.claude/skills/ubuntu-debloat/` (Linux only) |

Each skill has its own `README.md` with a plain-English overview, an
`SKILL.md` for Claude, and (where relevant) scripts under `scripts/`.
`hardened-shell` additionally has a deep user guide in
[`USAGE.md`](./.claude/skills/hardened-shell/USAGE.md).

## Installing a skill into your user profile

Skills in this repo auto-load when Claude Code runs **inside this
repo**. To make them available in every project, symlink each skill
you want into `~/.claude/skills/`.

### Linux / macOS

```bash
# one skill at a time (recommended — pick the ones you actually want)
ln -s ~/src/dev-setup/.claude/skills/end-session      ~/.claude/skills/end-session
ln -s ~/src/dev-setup/.claude/skills/hardened-shell   ~/.claude/skills/hardened-shell
ln -s ~/src/dev-setup/.claude/skills/review-plan      ~/.claude/skills/review-plan
ln -s ~/src/dev-setup/.claude/skills/ubuntu-debloat   ~/.claude/skills/ubuntu-debloat
```

### Windows

`ln -s` from Git Bash **silently falls back to a copy** unless
developer mode (or admin) is on — you end up with a duplicated skill
that doesn't follow updates. Use a directory junction instead:

```bash
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 cmd.exe /c mklink /J \
  'C:\Users\<you>\.claude\skills\<skill-name>' \
  'C:\Users\<you>\src\dev-setup\.claude\skills\<skill-name>'
```

Verify with `cmd //c dir <parent>` — a real link shows `<JUNCTION>` (or
`<SYMLINKD>`), **not** `<DIR>`.

### Project-scoped install (alternative)

If you only want a skill in one project, symlink it into that
project's `.claude/skills/` instead of your user profile. Same command,
different target.

## Extra install steps beyond symlinking

Most skills need only the symlink. Two need a little more:

- **`hardened-shell`** — also build the Docker image and install the
  `hshell` launcher. See
  [USAGE.md](./.claude/skills/hardened-shell/USAGE.md#installation).
- **`ubuntu-debloat`** — runs on Ubuntu only. The skill itself doesn't
  need anything extra installed; invoking it runs the numbered scripts
  in `scripts/`.

## Conventions for skills in this repo

- **Thin `SKILL.md`.** It's Claude's decision tree, not an instruction
  manual — the body tells Claude *when* to do what, scripts know *how*.
- **`README.md` per skill.** Human-facing plain-English overview. What
  it is, why it exists, what it does, how it's installed. Every skill
  should have one.
- **Tight frontmatter descriptions.** Descriptions load into context,
  so keep them short while still specific enough to trigger reliably.
- **Heavy lifting in `scripts/`.** Idempotent bash scripts, numerically
  ordered when there's a phase sequence, `--verify` mode where
  applicable.
- **Self-healing.** Skills that pin upstream versions (URLs, LTS
  releases, package names) include instructions for Claude to detect
  drift and update pinned values in place.
- **LTS / GA stable only.** Skills target the latest LTS or public-GA
  release, not bleeding-edge.

## Adding a new skill

1. Create `.claude/skills/<name>/SKILL.md` with YAML frontmatter
   (`name`, `description`) and a thin body.
2. Create `.claude/skills/<name>/README.md` — plain-English overview
   plus a clear **Installation intent** section (user-level,
   project-level, or both).
3. Put scripts in `.claude/skills/<name>/scripts/` (numerically
   ordered if there's a phase sequence; include a shared `lib.sh` if
   the skill is script-heavy — follow the pattern in `ubuntu-debloat`).
4. If the skill is user-facing (has a CLI or runtime the user drives
   directly), add a `USAGE.md` sibling for the deep how-to (see
   `hardened-shell/`).
5. Add an entry to [`claude-skills.md`](./claude-skills.md) with a
   one-line summary, entry point, and installation intent.
6. Add the skill to the **Skills at a glance** table in this README.

## Project mode

**Bringup.** Commits go straight to `main`, no feature branches, no
PR workflow yet. Promote to protected mode (and remove the breadcrumb
in `CLAUDE.md`) when the first feature branch + PR lands.

## Session history

See [`SESSION-SUMMARIES.md`](./SESSION-SUMMARIES.md) for dated entries
of what each session accomplished. Read the latest entry before
resuming work to avoid re-deriving context.
