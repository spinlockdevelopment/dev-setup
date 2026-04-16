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
Entry point: `scripts/run-all.sh` (or `scripts/run-all.sh --verify`)

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
User guide: [`USAGE.md`](./.claude/skills/hardened-shell/USAGE.md)
Entry points:
- `scripts/build-image.sh` — build `hshell:latest`
- `scripts/install.sh` — symlink `hshell` into `~/.local/bin`
- `scripts/verify.sh` — health check

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

### end-session

Path: `.claude/skills/end-session/`
User guide: [`README.md`](./.claude/skills/end-session/README.md)
Entry point: SKILL.md (triggered by `/end-session` or wrap-up phrases)

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
