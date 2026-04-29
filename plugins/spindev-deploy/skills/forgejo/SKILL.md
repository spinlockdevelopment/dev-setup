---
name: forgejo
description: Stand up a self-hosted Forgejo git server in Docker as a backup mirror for GitHub repos and a canonical home for on-prem-only / sensitive projects. Use when the user mentions self-hosting git, mirroring GitHub, "second copy" / backup of source, Forgejo, Gitea, gitbucket alternatives, codeberg-style hosting, on-prem git, pull-mirror, or wanting to escape GitHub-only durability. Pair with the `restic-backup` skill for point-in-time snapshots of the Forgejo data dir.
---

# forgejo — self-hosted backup git server

Thin skill. Real work lives in `scripts/` and `compose/`. You orchestrate:
bring the container up, configure pull-mirroring from GitHub, accept
direct pushes for on-prem-only repos, verify health.

## What forgejo gives the user

A working git server at `http(s)://<host>:3000` (web UI) + SSH on
`:2222` (or whatever port is free) where:

- **GitHub repos pull-mirror in** on a configurable interval. Mirrored
  refs come in non-forcefully — if upstream force-pushes, the next mirror
  fetch errors instead of silently overwriting history. Branch protection
  on the mirror side blocks delete and force-push from any source.
- **On-prem-only repos** push to Forgejo as their canonical remote.
  Identical SSH/HTTPS UX to GitHub — `git remote add forgejo
  ssh://git@<host>:2222/<user>/<repo>.git` and you're done.
- **Single data dir** at `./data/forgejo` (volume-mounted). Everything
  worth backing up — repos, attachments, LFS, DB if SQLite — lives here.
  The `restic-backup` skill snapshots this directory.

Pinned: Forgejo **v15.0.1** LTS (released 2026-04-29, supported through
2027-07-15). LTS-only per repo policy.

## Decision tree for Claude

### 1. "set up forgejo" / fresh bringup

```bash
scripts/bootstrap.sh <hostname>
# e.g. scripts/bootstrap.sh git.lan.example.com
```

What it does: copies `compose/docker-compose.yml` and `.env.example` to
`./forgejo/` in the user's chosen install dir, prompts for the admin
password, runs `docker compose up -d`, waits for the healthcheck, creates
the first admin user via `forgejo admin user create`, prints the web URL
and SSH clone string. Idempotent — safe to re-run; existing data is
preserved.

Default ports:
- Web UI: `3000` (host) → `3000` (container)
- SSH: `2222` (host) → `22` (container) — avoids host-SSH collision

If the user wants TLS, point an existing reverse proxy (Caddy, Traefik,
nginx) at `localhost:3000`. Forgejo's built-in TLS works too but a
sidecar proxy is the conventional path. **TLS setup is out of scope for
this skill** — we recommend Caddy for simplicity.

### 2. "mirror a GitHub repo" / "back up <repo> to forgejo"

```bash
scripts/add-mirror.sh <github-url> [interval]
# scripts/add-mirror.sh https://github.com/spinlockdevelopment/dev-setup 6h
```

Default interval: `6h0m0s`. Forgejo accepts Go-duration strings
(`1h`, `30m`, `24h`). The script:

1. Reads admin token from `~/.config/forgejo/admin-token` (created
   during bootstrap).
2. POSTs `/api/v1/repos/migrate` with `mirror: true`, `mirror_interval`,
   and `wiki: false` (no wiki mirroring — clutter).
3. Enables branch protection on the default branch with `enable_push:
   false`, `enable_force_push: false`, `enable_status_check: false` —
   nothing can rewrite history on the mirror side, even via the API.
4. Triggers an immediate sync.

The pull-mirror is **read-only on the Forgejo side**. Users can clone
from it but cannot push to it. That's correct — the source of truth is
GitHub.

### 3. "push an on-prem-only repo to forgejo"

```bash
scripts/create-repo.sh <repo-name> [--private]
# then on the user's laptop:
git remote add forgejo ssh://git@<host>:2222/<user>/<repo-name>.git
git push -u forgejo main
```

For private/sensitive projects, set `--private` (default). These repos
are NOT mirrored anywhere — Forgejo + the restic chain are the entire
durability story. Stress this to the user: losing both Forgejo and the
restic offsite means losing the project. That's why restic ships to
both NAS and R2.

### 4. "is forgejo healthy?" / "verify"

```bash
scripts/verify.sh
```

Checks: container running, web UI responding, SSH port reachable, last
mirror sync per repo (warns if any repo's `last_mirror_at` is older than
2× its interval), data dir size, free disk.

### 5. "back up forgejo data" → see the `restic-backup` skill

This skill provisions Forgejo. The `restic-backup` skill handles the
snapshot chain (NAS append-only + R2 offsite). They're decoupled on
purpose — you can use `restic-backup` against any directory.

## Self-healing

**This skill is served from a read-only plugin cache** (e.g.
`~/.claude/plugins/cache/spindev-deploy@spinlockdevelopment/<version>/`).
Edits there don't persist. Edit the authoritative copy at
`plugins/spindev-deploy/skills/forgejo/` in a clone of
`spinlockdevelopment/dev-setup`, commit (bringup: straight to `main`;
protected: feature branch + PR), push.

**Triggers for self-update:**

- Forgejo LTS rolls over (every ~12 months): bump
  `FORGEJO_VERSION` in `compose/docker-compose.yml` and the pinned
  version in this SKILL.md. Forgejo's LTS schedule lives at
  https://forgejo.org/releases/.
- Forgejo container image moves off `codeberg.org/forgejo/forgejo` →
  update the `image:` line.
- Forgejo API endpoints under `/api/v1/repos/migrate` change shape →
  fix `add-mirror.sh`.

Always update the dated `# pinned YYYY-MM-DD` comment when bumping a
version.

## Out of scope

- TLS termination. Use Caddy / Traefik / nginx in front. Forgejo's
  built-in TLS works but the conventional pattern is a reverse proxy.
- High availability. Single-node only. The whole point is "second
  place that fails differently than GitHub" — overengineering it
  defeats the purpose.
- Email / 2FA / OAuth setup. Out of band; configure via Forgejo's
  `app.ini` if needed.
- Push-mirror in the other direction (Forgejo → GitHub). Forgejo
  supports it, but for the typical use case here (GitHub canonical,
  Forgejo backup), you don't want it.

## Files

| File | Purpose |
|---|---|
| `compose/docker-compose.yml` | Forgejo + persistent volume + ports |
| `compose/.env.example` | Tunables (ports, version, install dir) |
| `scripts/bootstrap.sh` | First-time bringup; idempotent |
| `scripts/add-mirror.sh <url> [interval]` | Add a GitHub pull-mirror with branch protection |
| `scripts/create-repo.sh <name> [--private]` | Create an on-prem-only repo |
| `scripts/verify.sh` | Health check (`--verify` style) |
