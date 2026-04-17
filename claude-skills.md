# Claude skills index

Authoritative catalog of every skill in this repo. Update this file whenever
a skill is added, removed, or materially changed.

## Installing a skill elsewhere

Skills here auto-load when Claude Code runs inside this repo. To reuse one in
another project or your user profile, symlink it:

```bash
# project-level (autoload in the target project only)
ln -s ~/src/setup/.claude/skills/<name> <target-project>/.claude/skills/<name>

# user-level (autoload in every project for your user)
ln -s ~/src/setup/.claude/skills/<name> ~/.claude/skills/<name>
```

Keep symlinks — don't copy. That way updates in this repo propagate
everywhere the skill is installed.

On Windows, `ln -s` from Git Bash silently falls back to a copy unless
developer mode (or admin) is on. Use a directory junction instead:

```bash
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 cmd.exe /c mklink /J \
  'C:\Users\<you>\.claude\skills\<name>' \
  'C:\Users\<you>\src\dev-setup\.claude\skills\<name>'
```

Verify with `cmd //c dir <parent>` — a real link shows `<JUNCTION>` (or
`<SYMLINKD>`), not `<DIR>`.

## Skills

### ubuntu-debloat

Path: `.claude/skills/ubuntu-debloat/`
Human guide: [`README.md`](./.claude/skills/ubuntu-debloat/README.md)
Entry point: `scripts/run-all.sh` (or `scripts/run-all.sh --verify`)
Installation intent: **user-level** (Linux only) — symlink to `~/.claude/skills/ubuntu-debloat/` so Claude can run it from any project

Debloats a fresh Ubuntu desktop install and sets it up for Claude Code and
development. Removes games, office apps, Firefox, and snapd (with an apt pin
to keep it out). Installs Chrome, Docker CE, mise-managed Python/Node/Go/JDK,
Android Studio, and VS Code from native upstream repos. Enables
unattended-upgrades and `ufw`. Ships idempotent scripts with a `--verify`
mode and self-heals on upstream version drift (via
`scripts/check-versions.sh`).

Targets: Ubuntu 24.04+ desktop. Latest LTS / public-GA only.

### hardened-shell

Path: `.claude/skills/hardened-shell/`
Human overview: [`README.md`](./.claude/skills/hardened-shell/README.md)
Deep user guide: [`USAGE.md`](./.claude/skills/hardened-shell/USAGE.md)
Entry points:
- `scripts/build-image.sh` — build `hshell:latest`
- `scripts/install.sh` — symlink `hshell` into `~/.local/bin`
- `scripts/verify.sh` — health check

Installation intent: **user-level skill + user-level CLI** — symlink the skill to `~/.claude/skills/hardened-shell/` **and** run `scripts/install.sh` to put `hshell` on `$PATH` via `~/.local/bin`

Ships `hshell`, a launcher that drops into a hardened Docker sandbox so
Claude (and other agents) can run with `--dangerously-skip-permissions`
without risking the host. Host is bind-mounted read-only at `/host` with
a credential blocklist masking `.ssh`/`.aws`/`.gnupg`/`.netrc`/browser
profiles/etc. `$PWD` is the agent's only writable world at `/work`.
Per-project Claude state persists in `$PWD/.internal/claude/`. Subagents
share `/work` and coordinate via git worktrees under `/work/.worktree/`.

Image is Debian slim with mise-pinned Node + Python LTS, `claude-code`,
and common dev CLIs. Pins self-heal on LTS rollover (see SKILL.md).

Targets: any host with Docker CE. Latest LTS / public-GA only.

### review-plan

Path: `.claude/skills/review-plan/`
Human guide: [`README.md`](./.claude/skills/review-plan/README.md)
Entry point: SKILL.md (triggered by `/review-plan` or phrases like "review the plan", "harden the plan", "add checkpoints to the plan")
Installation intent: **user-level** — symlink to `~/.claude/skills/review-plan/` so the skill is available in any project that uses superpowers plans

Pre-implementation hardening pass for plans produced by `superpowers:writing-plans`. Runs a simplification review (inline, DRY/YAGNI/scope lens) plus an adversarial cross-model review (`/codex:adversarial-review`) over the plan document, lets the user triage findings, applies accepted edits, and — for long plans (6+ tasks) — injects explicit `### Checkpoint` blocks at logical subsystem/layer/dependency breaks. Short plans (≤5 tasks) skip checkpoint injection. Detects parallel-track plans and offers a worktree-per-track execution model so commits do not interleave and per-track `/codex:review --scope branch` stays clean. The injected checkpoint blocks dispatch both `superpowers:code-reviewer` (same-model) and `/codex:review` (cross-model) at each batch. After the skill runs, the user says "continue with implementation" and normal execution (`executing-plans` recommended) picks up, honoring the checkpoint blocks natively.

### sprites-dev

Path: `.claude/skills/sprites-dev/`
Human guide: [`README.md`](./.claude/skills/sprites-dev/README.md)
Entry point: SKILL.md (triggered by any mention of `sprite` CLI, sprites.dev API, `sprite exec`, `sprite api`, uploading into a sprite)
Installation intent: **project-level** — junction to `<project>/.claude/skills/sprites-dev/` in any repo that deploys to sprites.dev. Promote to user-level later if sprites are hit from multiple projects.

Correct-usage reference for the `sprite` CLI and sprites.dev API on
Windows / Git Bash. Every rule in the skill traces to an actual failure
seen in this project: Git Bash silently rewrites Unix-looking paths
before `sprite` sees them, breaking `sprite exec` flag parsing, `sprite
api` URLs, `--file` source:dest uploads, and `--dir`. The skill
codifies the `bash -c` wrapping pattern, the `MSYS_NO_PATHCONV=1`
prefix for API calls, the `sprite api <path> -- <curl-flags>` ordering,
and the compress-before-upload workaround for files over ~20 MB that
otherwise hit HTTP 502.

Targets: any host that drives sprites.dev; especially Windows/Git Bash.

### end-session

Path: `.claude/skills/end-session/`
Human guide: [`README.md`](./.claude/skills/end-session/README.md)
Entry point: SKILL.md (triggered by `/end-session` or wrap-up phrases)
Installation intent: **user-level** — symlink to `~/.claude/skills/end-session/` so wrap-up works in every project

User-level skill that wraps up a working session so a following `/clear`
loses nothing important. Detects bringup vs protected project mode, syncs
docs (`CLAUDE.md`, indexes, plans), reconciles TODOs, prunes stale
memory, runs local quality gates (tests/typecheck/lint), appends to
`SESSION-SUMMARIES.md`, syncs with `origin` to avoid orphaned-commit
confusion from squash merges, and — when work is clearly complete —
pushes a feature branch with PR + auto-merge + squash. Worktree-aware.
Asks before any destructive git op. Self-improves in place.

Installed user-wide via a Windows junction at
`~/.claude/skills/end-session` → this path.
