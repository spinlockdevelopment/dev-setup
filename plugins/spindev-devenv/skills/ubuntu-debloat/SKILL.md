---
name: ubuntu-debloat
description: Debloat Ubuntu desktop and set it up for Claude Code + development. Purges games, office apps, Firefox, snapd; installs Chrome (amd64), Brave (amd64+arm64), Docker CE, mise-managed Python/Node/Go/JDK, Android Studio, VS Code from upstream repos; supports idempotent re-runs via `--verify`. Use for fresh Ubuntu dev-box setup, debloat requests, installing dev toolchains on Ubuntu, verifying an existing Ubuntu dev env, or checking for drift/updates.
---

# Ubuntu debloat + dev setup

Thin skill. Real work lives in `scripts/`. You (Claude) orchestrate — read
the user's request, run the relevant script(s), report results, self-heal on
drift.

## What this does

- Purges games, office apps, Firefox, snapd, and default Ubuntu desktop bloat
- Installs Chrome (amd64) and Brave (amd64 + arm64) — Chromium-based browser
  coverage on both arches until Google ships arm64 Chrome debs
- Installs Docker CE, VS Code, Android Studio via native upstream repos
- Installs `mise` and uses it to manage Python, Node (LTS), Go, Java (LTS)
- Adds common dev CLI tools (ripgrep, fd, bat, fzf, gh, jq, tmux, etc.)
- Enables `unattended-upgrades` for security patches
- Ships a `verify` mode that checks health on re-run

## Target versions

Latest **public GA stable or LTS** — NOT cutting edge. If a user asks for
nightly/beta, push back — that's out of scope for this skill.

## How to run

Scripts are **idempotent** — re-running is safe and cheap. They live in
`scripts/` and are numerically ordered. The orchestrator is
`scripts/run-all.sh`. Pass `--verify` to check state without making changes.

```bash
# full run on a fresh machine
./scripts/run-all.sh

# re-check everything, make no changes (fast, read-only)
./scripts/run-all.sh --verify

# run one phase
./scripts/70-install-docker.sh
```

Each script:
- starts with `set -euo pipefail`
- sources `scripts/lib.sh` for shared logging + idempotency helpers
- logs `[OK]` / `[SKIP]` / `[FAIL]` per action
- exits 0 if already-applied
- exits non-zero only on real failure

## Decision tree for Claude

1. **"set up my machine" on a fresh install** → confirm OS version (≥ 24.04),
   run `00-preflight.sh` (snapshots the package list first), then
   `run-all.sh`.
2. **"re-run" or "verify"** → `run-all.sh --verify`. Report what passed,
   what's out of date, what's missing. Offer to fix.
3. **"install one thing"** → run the relevant numbered script.
4. **"am I up to date?"** → `99-verify.sh` then `check-versions.sh`.

On a machine that isn't a fresh install, **confirm before destructive steps**
and make sure `00-preflight.sh` snapshotted the package list first.

## Self-healing — important

This skill outlives any single release. Upstream drifts: package names get
renamed, repo URLs change, LTS versions roll over, Ubuntu ships a new
codename. When you (Claude) notice drift, update this skill and its scripts
so the next run self-heals.

**This skill is served from a read-only plugin cache** (`~/.claude/plugins/cache/spindev-devenv@spinlockdevelopment/<version>/`). Edits to `SKILL.md` or `scripts/` there do not persist and do not propagate. Edit the authoritative copy at `plugins/spindev-devenv/skills/ubuntu-debloat/` in a clone of `spinlockdevelopment/dev-setup`, commit (bringup: straight to `main`; protected: feature branch + PR), and push. Consumers pick it up on their next `/plugin marketplace update`.

**Triggers for self-update:**
- `check-versions.sh` reports a pinned version is stale (e.g., JDK LTS
  moved from 21 → 25; Android Studio URL has a newer version).
- A script fails because an apt package was renamed or dropped.
- Ubuntu codename logic in `00-preflight.sh` doesn't know about a new release.
- A repo GPG key rotated.

**What to do when you detect drift:**
1. Fix the failing script to work with current reality.
2. Update the pinned version / URL / package name.
3. Prefer the new LTS over the old one — we target LTS, not latest.
4. Drop a short dated comment near the updated value, e.g.
   `# bumped JDK 21 → 25 on 2026-04-13 (new LTS)`.
5. If in a git repo, offer to commit the change with a clear message.
6. Re-run the affected script to verify.

**Also check periodically even without a failure:** when the user invokes
this skill, spend a moment running `scripts/check-versions.sh`. If it finds
pinned versions that have been superseded by a newer LTS, update the scripts
before running them — don't wait for something to break.

**What NOT to do:**
- Don't silently swallow failures and call them passes.
- Don't pin to bleeding-edge to work around a transient upstream issue.
- Don't add new functionality to the skill while self-healing — keep those
  changes focused on restoring correctness.

## Out of scope

- Dotfiles, shell configuration
- SSH key generation
- Firewall rules beyond `ufw` defaults
- Desktop theming / GNOME extensions
- Work laptops under MDM (this skill will fight the policy and lose)

## Files

| File | Purpose |
|---|---|
| `scripts/lib.sh` | Shared helpers: logging, idempotent apt install/purge, OS gate |
| `scripts/00-preflight.sh` | OS version check, snapshot of current package state |
| `scripts/05-sudoers-nopasswd.sh` | Install ephemeral `/etc/sudoers.d/ubuntu-debloat` with narrow NOPASSWD rules so later phases don't prompt. Reverted by `run-all.sh`'s EXIT trap (single-user dev box only) |
| `scripts/10-update.sh` | `apt update`/`upgrade`, enable unattended-upgrades |
| `scripts/20-debloat.sh` | Purge games, office apps, Firefox, misc GNOME bloat |
| `scripts/30-remove-snap.sh` | Completely remove snapd |
| `scripts/40-install-core.sh` | `build-essential` + common CLI tools |
| `scripts/50-install-chrome.sh` | Google Chrome from Google's apt repo (amd64 only) |
| `scripts/51-install-brave.sh` | Brave from Brave's apt repo (amd64 + arm64) |
| `scripts/60-install-mise.sh` | mise + Python / Node (LTS) / Go / JDK (LTS) |
| `scripts/70-install-docker.sh` | Docker CE from docker.com repo |
| `scripts/80-install-android.sh` | Android Studio + platform tools |
| `scripts/90-install-vscode.sh` | VS Code from Microsoft's apt repo |
| `scripts/99-verify.sh` | Health check across everything above |
| `scripts/run-all.sh` | Orchestrator; accepts `--verify` |
| `scripts/check-versions.sh` | Upstream version drift check |
