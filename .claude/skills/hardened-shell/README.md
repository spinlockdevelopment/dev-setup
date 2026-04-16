# hardened-shell

A Claude Code skill that ships `hshell` — a launcher that drops you (or
an agent) into a hardened Docker sandbox where
`claude --dangerously-skip-permissions` can run without putting the
host at risk.

## Purpose

"Banshee mode" (`--dangerously-skip-permissions`) is genuinely useful
for long agentic runs, but running it directly on your host means any
command the agent issues lands on your real filesystem with your real
credentials in reach. `hshell` keeps the productivity of banshee mode
while containing the blast radius.

## Why it exists

- Agents occasionally do destructive things. A sandbox turns a
  potential outage into a discardable `/work` mount.
- Credentials on a dev box are everywhere (`~/.ssh`, `~/.aws`,
  `~/.gnupg`, browser profiles, shell history). A blocklist removes
  them from the agent's view.
- Subagents running in parallel need a way to stay out of each other's
  way — `hshell` integrates with git worktrees so siblings don't
  stomp on each other's edits.
- Per-project Claude memory is valuable and should persist — but only
  for that project. `hshell` scopes state under `$PWD/.internal/claude/`.

## What it does

- Builds `hshell:latest` from a Debian-slim base with Node LTS +
  Python (latest stable) via `mise`, `claude-code`, `gh`, `ripgrep`,
  `jq`, `doppler`, and the usual dev CLIs.
- Runs the container with caps dropped, `no-new-privileges`, an
  8 GB memory cap, and a 512-pid cap.
- Bind-mounts your `$PWD` as `/work` (read-write, the only writable
  world).
- Bind-mounts the host at `/host` **read-only**, with a blocklist
  masking `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`, `~/.docker`,
  `~/.netrc`, `~/.pgpass`, `~/.password-store`, `~/.mozilla`, browser
  profiles, keyrings, shell history, `/root`, `/etc/shadow`, and
  more.
- Persists per-project Claude state at `$PWD/.internal/claude/`
  (memory, MCP servers, settings) and appends `.internal/` to
  `.gitignore` on first run in a git repo.
- Supports multiple parallel invocations via git worktrees under
  `/work/.worktree/`.
- Refuses to run in `$HOME` or `/` (would defeat the point).

## How to use it

Install once, then invoke from any project directory:

```bash
hshell                    # interactive bash inside the sandbox
hshell claude             # claude with --dangerously-skip-permissions auto-injected
hshell claude -p "..."    # one-shot agent run, then exit
hshell <any command>      # execute that command inside the sandbox
```

For the full user-facing guide — install steps, credential handling,
subagent/worktree pattern, rebuild/bump-pin workflow, troubleshooting,
security notes, customization — see [`USAGE.md`](./USAGE.md).

For the Claude-facing decision tree (when to invoke, self-healing
rules on LTS drift) see [`SKILL.md`](./SKILL.md).

## Installation intent

**User-level skill + user-level CLI.**

The CLI (`hshell`) installs to `~/.local/bin` via
`./scripts/install.sh` — no sudo, no root. The skill directory should
be symlinked to `~/.claude/skills/hardened-shell/` so Claude knows
about `hshell` in any project.

One-time setup from this repo:

```bash
# 1. build the base image (takes ~1–8 min)
./.claude/skills/hardened-shell/scripts/build-image.sh

# 2. symlink the hshell launcher into ~/.local/bin
./.claude/skills/hardened-shell/scripts/install.sh

# 3. health check
./.claude/skills/hardened-shell/scripts/verify.sh

# 4. expose the skill user-wide
#    Linux / macOS:
ln -s ~/src/dev-setup/.claude/skills/hardened-shell ~/.claude/skills/hardened-shell
#    Windows (Git Bash, no admin needed):
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 cmd.exe /c mklink /J \
  'C:\Users\<you>\.claude\skills\hardened-shell' \
  'C:\Users\<you>\src\dev-setup\.claude\skills\hardened-shell'
```

See `claude-skills.md` in the repo root for the general install
pattern.

## Requirements

- Docker CE (the `ubuntu-debloat` skill in this repo installs it).
- A glibc-based host. Linux primary; macOS works with Docker Desktop;
  Windows works under WSL2.
- Your user in the `docker` group (`sudo usermod -aG docker "$USER"`
  and log back in).

## Files

| File | Purpose |
|---|---|
| `SKILL.md` | Claude-facing decision tree |
| `README.md` | This file — overview + install intent |
| `USAGE.md` | Full human-facing user guide |
| `Dockerfile` | Base image definition (LTS-pinned Node/Python) |
| `home-template/` | Seed content for `$PWD/.internal/claude/` |
| `scripts/build-image.sh` | Build `hshell:latest` |
| `scripts/install.sh` | Symlink `hshell` into `~/.local/bin` |
| `scripts/verify.sh` | Health check |
| `scripts/hshell` | The launcher itself |
