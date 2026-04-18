---
name: hardened-shell
description: Run Claude (or other agents) in banshee mode — `--dangerously-skip-permissions`, no prompts — inside a locked-down Docker sandbox called `hshell`. Host is read-only at `/host` with credentials masked; `$PWD` is the agent's only writable world at `/work`; Claude memory persists per project in `$PWD/.internal/claude/`. Use when the user says "hshell", "run this in a sandbox", "let claude loose", "yolo mode", or asks for a hardened environment to dispatch agents/subagents from. Also use when the user wants to install or verify `hshell`, build the image, or rotate LTS pins.
---

# hardened-shell — `hshell`

Thin skill. Real work lives in `scripts/` and `Dockerfile`. You orchestrate:
build the image, install the launcher, verify health, or — if something
breaks — self-heal the pins.

## What hshell gives the user

A single command, `hshell`, that runs a Docker container where:

- **Host is read-only** at `/host`. The agent can read any tool or file on
  the host, but cannot modify anything outside `/work`.
- **`$PWD` is writable** at `/work`. This is the agent's only write surface.
- **Sensitive host paths are masked** (blocklist): `~/.ssh`, `~/.aws`,
  `~/.gnupg`, `~/.kube`, `~/.docker`, `~/.netrc`, `~/.pgpass`, browser
  profiles, `~/.config/{gh,doppler,op}`, `~/.password-store`, shell history,
  keyrings, `/root`, `/etc/shadow`. The agent pulls creds from `/work/.env`
  or project-scoped Doppler instead.
- **Per-project Claude state** lives in `$PWD/.internal/claude/`, seeded
  from `home-template/` on first run. Survives across invocations. The
  agent's writes diverge freely per project; the template stays clean.
- **Banshee mode** — the launcher injects `--dangerously-skip-permissions`
  when invoked as `hshell claude`. The sandbox is the safety net.

## Usage

```bash
hshell                    # interactive bash in the sandbox
hshell claude             # claude with --dangerously-skip-permissions auto-injected
hshell claude -p "..."    # one-shot agent run
hshell <any command>      # exec the command inside the sandbox
```

Subagents can spawn more `hshell` invocations in the same project — they
share `/work`, so they should use git worktrees under `/work/.worktree/`
to avoid stepping on each other.

## Decision tree for Claude

1. **"install hshell" / fresh setup** →
   `scripts/build-image.sh` then `scripts/install.sh`. Verify with
   `scripts/verify.sh`. The launcher symlinks into `~/.local/bin/hshell`
   (no sudo required).
2. **"is hshell healthy?" / "verify"** → `scripts/verify.sh`.
3. **"rebuild the image" / after Dockerfile edits** →
   `scripts/build-image.sh --force`.
4. **"it's broken"** → `scripts/verify.sh` first, fix the specific failure.

## Self-healing

Upstream drifts. When you (Claude) hit any of these, **update in place**:

- `npm install -g @anthropic-ai/claude-code` fails or installs an ancient
  version → check for package rename or newer major.
- Node or Python LTS rolls over (October for Node, October for Python) →
  run `mise latest node@lts` / `mise latest python` on the host, bump the
  `NODE_LTS_VERSION` / `PYTHON_VERSION` pins in `Dockerfile`, update the
  dated comment, rebuild with `build-image.sh --force`.
- Debian stable moves to a new codename and the base image shifts → no
  action needed (`debian:stable-slim` floats), but verify the build still
  succeeds.
- An apt package gets renamed (e.g. `fd-find` → `fd`) → fix the Dockerfile,
  rebuild.
- Doppler / gh install script URL changes → update in Dockerfile, rebuild.

**Always** update the dated `# pinned YYYY-MM-DD` comment when you bump a
version so the next reviewer can see when it was last touched.

**Never** drop sandbox guarantees to work around a build problem. If
`--user` mapping or the blocklist is fighting you, fix the real issue;
do not remove them.

## Out of scope

- Sandbox escape prevention against a malicious container image. We trust
  `hshell:latest` (we built it) and Anthropic's `claude-code` package.
- Network-layer restrictions (egress filtering, LAN blocking). If the
  threat model includes container-to-host localhost services, add
  `--network=none` or custom iptables separately.
- Host writes. Refused by design. If the agent needs to edit the host,
  the user should run the task outside `hshell`.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | `hshell:latest` image — Debian slim + mise-pinned Node/Python LTS + claude-code + dev CLIs |
| `home-template/CLAUDE.md` | Tells the agent it is sandboxed, what it can/can't see |
| `home-template/settings.json` | Permissive Claude settings (defensive; mostly moot with `--dangerously-skip-permissions`) |
| `scripts/lib.sh` | Shared logging + docker helpers |
| `scripts/hshell` | The launcher — computes mounts, execs `docker run` |
| `scripts/build-image.sh` | Build `hshell:latest` (idempotent; `--force` to rebuild) |
| `scripts/install.sh` | Symlink `hshell` into `~/.local/bin` |
| `scripts/verify.sh` | Read-only health check across image + launcher + tools |
