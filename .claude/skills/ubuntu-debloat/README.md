# ubuntu-debloat

A Claude Code skill that debloats a fresh Ubuntu desktop install and
sets it up for Claude Code + general development.

## Purpose

New Ubuntu installs ship with games, office apps, Firefox-as-snap, and
a pile of default desktop bloat you don't want on a dev box. Setting up
a clean, reproducible dev environment by hand is tedious and
error-prone. This skill turns it into a single command, safe to re-run,
with a `--verify` mode that reports drift without touching anything.

## Why it exists

- Manual setup drifts across machines — every new laptop ends up
  slightly different.
- Snap is actively hostile to developer workflows (slow launches,
  confinement issues, auto-updates). Removing it properly (with an apt
  pin so it doesn't come back) is more steps than you'd expect.
- Upstream repos (Google, Docker, Microsoft, Anthropic) each have their
  own install dance. Doing it from memory leads to mistakes.
- Pinned tool versions drift as new LTS releases land — the skill
  self-heals when it notices.

## What it does

- **Purges** games, default office apps, Firefox (incl. snap), snapd
  itself (with an apt pin), and miscellaneous GNOME desktop bloat.
- **Installs** Chrome, Docker CE, VS Code, Android Studio from native
  upstream apt repos.
- **Manages languages via `mise`:** Python, Node (LTS), Go, Java (LTS).
- **Adds common dev CLIs:** `ripgrep`, `fd`, `bat`, `fzf`, `gh`, `jq`,
  `tmux`, etc.
- **Enables `unattended-upgrades`** so security patches land
  automatically.
- **Ships a `--verify` mode** — read-only, reports what's missing or
  drifted.
- **Self-heals on upstream drift** — new LTS, renamed packages, rotated
  GPG keys — Claude updates the pinned values in place and the next run
  works.

## Target versions

Latest **public GA stable or LTS** — never cutting-edge. If something
asks for nightly or beta, that's out of scope.

## How to run

Scripts are numerically ordered and live in `scripts/`. The
orchestrator is `scripts/run-all.sh`.

```bash
# fresh machine — full run
./scripts/run-all.sh

# re-check everything, make no changes (fast, read-only)
./scripts/run-all.sh --verify

# install one phase only
./scripts/70-install-docker.sh
```

Each script starts with `set -euo pipefail`, sources `scripts/lib.sh`
for shared helpers, logs `[OK]` / `[SKIP]` / `[FAIL]` per action, exits
0 when already-applied, and only exits non-zero on real failure.

## Requirements

- Ubuntu 24.04 LTS or newer desktop.
- `sudo` access (the skill installs an ephemeral
  `/etc/sudoers.d/ubuntu-debloat` with narrow NOPASSWD rules for its own
  phases, reverted on exit — single-user dev box assumption).
- A clean-ish install. On a machine that's already been customised,
  `00-preflight.sh` snapshots the current package list first so you can
  see what changed.

## Out of scope

- Dotfiles and shell configuration.
- SSH key generation.
- Firewall rules beyond `ufw` defaults.
- Desktop theming / GNOME extensions.
- Work laptops under MDM (the skill will fight the policy and lose).

## Installation intent

**User-level recommended.** You typically run this once per new
machine, but having it installed at `~/.claude/skills/ubuntu-debloat/`
means Claude can reach it in any session when you say "set up my dev
box" without needing to `cd ~/src/dev-setup` first.

Symlink from this repo so updates propagate:

```bash
# Linux (this skill only runs on Linux anyway)
ln -s ~/src/dev-setup/.claude/skills/ubuntu-debloat ~/.claude/skills/ubuntu-debloat
```

Alternatively, keep it project-scoped to this repo and just invoke it
by path — `cd ~/src/dev-setup && ./.claude/skills/ubuntu-debloat/scripts/run-all.sh`
— if you prefer not to expose it globally.

## Self-healing

This skill outlives any single release. When Claude notices drift (new
LTS out, package renamed, repo URL moved, GPG key rotated):

1. Fix the failing script to match current reality.
2. Update pinned versions / URLs / package names in place.
3. Prefer the new LTS over the old one.
4. Drop a dated comment near the change, e.g.
   `# bumped JDK 21 → 25 on 2026-04-13 (new LTS)`.
5. Re-run the affected script to verify.
6. If in a git repo, offer to commit.

`scripts/check-versions.sh` runs drift checks without making changes.

## Files

| File | Purpose |
|---|---|
| `SKILL.md` | Claude-facing decision tree |
| `README.md` | This file — human-facing overview |
| `scripts/lib.sh` | Shared helpers (logging, idempotent apt install/purge, OS gate) |
| `scripts/00-preflight.sh` | OS version check + package-list snapshot |
| `scripts/05-sudoers-nopasswd.sh` | Ephemeral sudoers rules for later phases |
| `scripts/10-update.sh` | `apt update`/`upgrade` + unattended-upgrades |
| `scripts/20-debloat.sh` | Purge games, office apps, Firefox, GNOME bloat |
| `scripts/30-remove-snap.sh` | Remove snapd + apt-pin it out |
| `scripts/40-install-core.sh` | `build-essential` + common CLI tools |
| `scripts/50-install-chrome.sh` | Google Chrome |
| `scripts/60-install-mise.sh` | `mise` + Python / Node / Go / JDK |
| `scripts/70-install-docker.sh` | Docker CE |
| `scripts/80-install-android.sh` | Android Studio + platform tools |
| `scripts/90-install-vscode.sh` | VS Code |
| `scripts/99-verify.sh` | Cross-phase health check |
| `scripts/run-all.sh` | Orchestrator (accepts `--verify`) |
| `scripts/check-versions.sh` | Upstream version drift check |
