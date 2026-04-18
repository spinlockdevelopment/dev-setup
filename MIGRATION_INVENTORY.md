# Migration Inventory

Audit of every skill and slash-command in this repo prior to refactoring into
a multi-plugin marketplace. Produced per Step 1 of the porting guide.

Generated: 2026-04-18.

## Skills

### `end-session`

- **Current path:** `.claude/skills/end-session/`
- **New path:** `plugins/spindev-core/skills/end-session/`
- **Frontmatter `name`:** `end-session`
- **Frontmatter `description`:** Wraps up a working session cleanly so a following /clear loses nothing important — syncs docs, prunes and updates memory, reconciles TODOs, runs local quality gates, writes a session summary, and (when appropriate) creates a PR with auto-merge + squash. Use this skill whenever the user invokes /end-session or says phrases like "get ready to clear context", "wrap up this session", "prep for /clear", "we're done for now", "let's wrap up", or otherwise signals the session is ending. This skill is itself the explicit permission to create a PR and enable auto-merge when session context clearly indicates feature work is complete.
- **Files:**
  - `SKILL.md`
  - `README.md`

### `init-project`

- **Current path:** `.claude/skills/init-project/`
- **New path:** `plugins/spindev-core/skills/init-project/`
- **Frontmatter `name`:** `init-project`
- **Frontmatter `description`:** Bring a project up to baseline for working with Claude — ensure it's a git repo on `main`, detect bringup vs protected mode and manage the breadcrumb accordingly, scaffold missing `CLAUDE.md`/`README.md`, stamp the canonical PR-workflow rules block into `CLAUDE.md`, auto-junction dev-setup-owned dependency skills (`end-session`, `review-plan`) into `~/.claude/skills/`, and report missing plugin skills (`simplify`, `codex`, `superpowers`, `claude-md-management`) with install commands. Safe to re-run. Triggers: `/init-project`, "initialize this project", "set up this repo for Claude", "bring this project up to baseline".
- **Files:**
  - `SKILL.md`
  - `README.md`
  - `scripts/detect-mode.sh`
  - `scripts/install-dep-skill.sh`
  - `scripts/lib.sh`

### `review-plan`

- **Current path:** `.claude/skills/review-plan/`
- **New path:** `plugins/spindev-core/skills/review-plan/`
- **Frontmatter `name`:** `review-plan`
- **Frontmatter `description`:** Run a cross-model pre-implementation review on a superpowers plan, apply accepted findings, and inject checkpoint review blocks at logical subsystem breaks so long plans get batched cross-model reviews instead of per-task reviews. Supports parallel-track plans (one worktree per track). Use when the user invokes `/review-plan` or says phrases like "review the plan", "harden the plan", "add checkpoints to the plan", or "cross-model review the plan" after a plan has been generated (typically by superpowers:writing-plans). Skip checkpoint injection for short plans (≤5 tasks) — they do not benefit from batching.
- **Files:**
  - `SKILL.md`
  - `README.md`
  - `assets/checkpoint-template.md`
  - `assets/parallel-tracks-note.md`
  - `assets/plan-header-note.md`

### `hardened-shell`

- **Current path:** `.claude/skills/hardened-shell/`
- **New path:** `plugins/spindev-devenv/skills/hardened-shell/`
- **Frontmatter `name`:** `hardened-shell`
- **Frontmatter `description`:** Run Claude (or other agents) in banshee mode — `--dangerously-skip-permissions`, no prompts — inside a locked-down Docker sandbox called `hshell`. Host is read-only at `/host` with credentials masked; `$PWD` is the agent's only writable world at `/work`; Claude memory persists per project in `$PWD/.internal/claude/`. Use when the user says "hshell", "run this in a sandbox", "let claude loose", "yolo mode", or asks for a hardened environment to dispatch agents/subagents from. Also use when the user wants to install or verify `hshell`, build the image, or rotate LTS pins.
- **Files:**
  - `SKILL.md`
  - `README.md`
  - `USAGE.md`
  - `Dockerfile`
  - `home-template/CLAUDE.md`
  - `home-template/settings.json`
  - `scripts/build-image.sh`
  - `scripts/hshell` (launcher binary)
  - `scripts/install.sh`
  - `scripts/lib.sh`
  - `scripts/verify.sh`

### `ubuntu-debloat`

- **Current path:** `.claude/skills/ubuntu-debloat/`
- **New path:** `plugins/spindev-devenv/skills/ubuntu-debloat/`
- **Frontmatter `name`:** `ubuntu-debloat`
- **Frontmatter `description`:** Debloat Ubuntu desktop and set it up for Claude Code + development. Purges games, office apps, Firefox, snapd; installs Chrome (amd64), Brave (amd64+arm64), Docker CE, mise-managed Python/Node/Go/JDK, Android Studio, VS Code from upstream repos; supports idempotent re-runs via `--verify`. Use for fresh Ubuntu dev-box setup, debloat requests, installing dev toolchains on Ubuntu, verifying an existing Ubuntu dev env, or checking for drift/updates.
- **Files:**
  - `SKILL.md`
  - `README.md`
  - `scripts/lib.sh`
  - `scripts/00-preflight.sh`
  - `scripts/05-sudoers-nopasswd.sh`
  - `scripts/10-update.sh`
  - `scripts/20-debloat.sh`
  - `scripts/30-remove-snap.sh`
  - `scripts/40-install-core.sh`
  - `scripts/50-install-chrome.sh`
  - `scripts/51-install-brave.sh`
  - `scripts/60-install-mise.sh`
  - `scripts/70-install-docker.sh`
  - `scripts/80-install-android.sh`
  - `scripts/90-install-vscode.sh`
  - `scripts/99-verify.sh`
  - `scripts/check-versions.sh`
  - `scripts/run-all.sh`

### `sprites-dev`

- **Current path:** `.claude/skills/sprites-dev/`
- **New path:** `plugins/spindev-deploy/skills/sprites-dev/`
- **Frontmatter `name`:** `sprites-dev`
- **Frontmatter `description`:** Use when running any `sprite` CLI command or calling the sprites.dev API from Windows/Git Bash — prevents path mangling, flag-ordering bugs, and large-file upload failures. Trigger on any mention of Fly.io Sprites, sprites.dev, `sprite exec`, `sprite api`, `sprite console`, `sprite checkpoint`, `sprite url`, uploading files into a sprite, or deploying/restarting a service in a sprite.
- **Files:**
  - `SKILL.md`
  - `README.md`

## Slash commands

All three existing slash-command wrappers delegate to same-named skills in
`spindev-core`, so they ship with that plugin.

### `end-session.md`

- **Current path:** `.claude/commands/end-session.md`
- **New path:** `plugins/spindev-core/commands/end-session.md`
- **Description (frontmatter):** Wrap up the current working session cleanly so a following /clear loses nothing important
- **Delegates to:** `end-session` skill

### `init-project.md`

- **Current path:** `.claude/commands/init-project.md`
- **New path:** `plugins/spindev-core/commands/init-project.md`
- **Description (frontmatter):** Bring this project up to baseline for working with Claude — git init (if needed), mode breadcrumb, minimal CLAUDE.md / README.md, PR-workflow rules block, dependency skills
- **Delegates to:** `init-project` skill

### `review-plan.md`

- **Current path:** `.claude/commands/review-plan.md`
- **New path:** `plugins/spindev-core/commands/review-plan.md`
- **Description (frontmatter):** Pre-implementation hardening pass on a superpowers plan — cross-model review plus checkpoint-block injection
- **Delegates to:** `review-plan` skill

## Unaffected assets

Left in place by this refactor:

- `SESSION-SUMMARIES.md` — append-only session log
- `docs/superpowers/plans/` + `docs/superpowers/specs/` — plan/spec archive
- `.gitignore`

## Docs rewritten in Step 8

- `README.md` — rewritten for marketplace consumers
- `claude-skills.md` — skill paths updated
- `CLAUDE.md` — symlink/junction narrative replaced with marketplace conventions

## Summary

- 6 skills moved, 3 slash-commands moved → 9 `git mv`s total (each moves a
  whole folder / file, not individual children).
- 3 new plugins created: `spindev-core`, `spindev-devenv`, `spindev-deploy`.
- 0 `SKILL.md` bodies or frontmatter values modified.
