---
name: restic-backup
description: Stand up an encrypted, two-destination restic backup chain — append-only NAS share via rest-server (primary, fast, cheap) plus Cloudflare R2 with write-only API credentials (offsite, immutable). Use when the user mentions backups, restic, borg, append-only, write-only credentials, NAS share, R2 / S3 / object storage backup, healthchecks.io, restore drills, ransomware-resistant backup, "second copy of source", or pairs with the `forgejo` skill to back up `./data/forgejo`. Also use to add new directories to an existing chain or to run a restoration drill.
---

# restic-backup — append-only NAS + Cloudflare R2

Thin skill. Real work lives in `scripts/` and `systemd/`. You orchestrate
install, repo init, scheduling, and restore drills.

## What this gives the user

A daily encrypted backup chain that survives both ransomware on the
source box and credential leak from the source box:

```
source dir (e.g. ./data/forgejo, /home/me/projects)
   │
   │  restic backup  (laptop/server creds: read source, write to NAS)
   ▼
NAS rest-server in --append-only mode
   │  (creds CAN write new snapshots, CANNOT delete or modify existing)
   │
   │  restic copy  (laptop/server creds: read NAS, write R2)
   ▼
Cloudflare R2 bucket
   (R2 token scoped to PutObject only — no DeleteObject;
    optionally R2 object-lock for true WORM)
   │
   ▼
healthchecks.io ping  ← pages user if a daily run is missed
```

Restic is **always encrypted** (no plaintext mode), so the R2 leg is
encrypted by default. The NAS leg is encrypted too — meaning a NAS
breach also doesn't expose source.

Pinned: restic **0.18.1**, rest-server **v0.14.0**. LTS/stable only.

## Decision tree for Claude

### 1. "set up backups" / fresh chain

Three boxes are involved. Claude handles whichever is currently in
front of it:

**A. Source box** (the thing being backed up — Forgejo host, dev box):
```bash
scripts/install-restic.sh             # idempotent; --verify to check
scripts/init-repos.sh                 # interactive: prompts for NAS URL, R2 creds, password
scripts/install-systemd-units.sh      # daily timer + service
```

**B. NAS** (a Linux box / Synology / TrueNAS Scale that exposes a share
or runs its own services):
```bash
scripts/install-rest-server.sh        # installs binary + systemd unit (--append-only)
```
Run this on the NAS itself, OR copy `systemd/rest-server.service` and
follow the README's NAS-specific notes.

**C. Cloudflare** (browser only — no script can mint R2 tokens
without an API key already in hand). The `init-repos.sh` script prints
the exact dashboard steps before asking for the resulting credentials.

### 2. "add a directory to the backup"

```bash
scripts/add-source.sh <path> [tag]
# scripts/add-source.sh /srv/forgejo/data forgejo
# scripts/add-source.sh /home/me/projects projects
```

Appends to `~/.config/restic-backup/sources.list`. The systemd unit
reads that file and snapshots every entry on each run with the given
tag.

### 3. "run a backup now"

```bash
systemctl start restic-backup.service        # one-shot run via systemd
# or
scripts/run-backup.sh                        # same logic, foreground
```

`run-backup.sh` is what the systemd unit invokes. It backs up to NAS,
`restic copy`s NAS → R2 (no double snapshot), prunes per retention
policy, and pings healthchecks on success.

### 4. "verify the chain"

```bash
scripts/verify.sh
```

Checks: restic + rest-server installed, NAS repo reachable, R2 repo
reachable, both repos pass `restic check --read-data-subset 1%`,
last successful run within the timer interval, healthchecks.io URL
responds.

### 5. "restore drill" / "did this actually work?"

```bash
scripts/restore-drill.sh                                # restores latest forgejo snapshot to /tmp/restic-drill
scripts/restore-drill.sh --tag projects --dest /tmp/d   # specific tag, custom dest
```

Pulls the latest snapshot for a tag, restores to a scratch dir, and
runs `git fsck` against any bare repos found inside (since the typical
payload is a Forgejo data dir). Treat untested backups as no backups.

### 6. "rotate restic password" / "rotate R2 token"

Restic password: `restic key add` then `restic key remove <old>` —
the encryption key is shared between NAS and R2 repos, so add+remove
once per repo.

R2 token: rotate in the Cloudflare dashboard, update
`~/.config/restic-backup/r2.env`, no other action needed (next run
picks up new creds). Same shape for healthchecks.io URL.

## Why this shape

| Choice | Reason |
|---|---|
| **Two destinations, not one** | NAS is fast & cheap (LAN speed, no egress). R2 covers physical-site loss (fire, theft, NAS death). |
| **`restic copy` from NAS → R2** | Single snapshot pass on the source; copy preserves dedup; R2 leg never re-reads source data. |
| **Append-only `rest-server`** | Server-side enforcement: even if the source box is fully compromised and creds stolen, attacker cannot delete existing NAS snapshots. Filesystem perms can't enforce this — `rest-server --append-only` can. |
| **R2 token: PutObject only** | Same as above for R2: a leaked source-box token can't `DeleteObject`. Optional R2 object-lock layers WORM on top. |
| **Cloudflare R2 over B2/S3** | User already on Cloudflare. R2 has zero egress fees (free restoration), S3-compatible API works with restic. |
| **Healthchecks ping** | Silent failures are the realistic threat. Cron jobs that have been broken for 6 months are common; HC pages on missed pings. |
| **Restore drill script** | "Backups exist" ≠ "backups work". Drill at least once after setup and quarterly thereafter. |

## Self-healing

**This skill is served from a read-only plugin cache.** Edit the
authoritative copy at `plugins/spindev-deploy/skills/restic-backup/`
in a clone of `spinlockdevelopment/dev-setup`, commit, push.

**Triggers for self-update:**

- restic stable rolls (https://github.com/restic/restic/releases) →
  bump `RESTIC_VERSION` in `scripts/install-restic.sh` and the pin
  in this SKILL.md. Update dated `# pinned YYYY-MM-DD` comment.
- rest-server stable rolls
  (https://github.com/restic/rest-server/releases) → bump
  `REST_SERVER_VERSION` in `scripts/install-rest-server.sh`.
- Restic CLI flags drift (rare — restic is conservative) → fix in
  `run-backup.sh` and `restore-drill.sh`.
- Cloudflare R2 endpoint hostname changes (currently
  `<accountid>.r2.cloudflarestorage.com`) → fix in `init-repos.sh`
  prompts and `r2.env.example`.

## Out of scope

- Database-aware backups (Postgres / MySQL dumps before snapshot). For
  Forgejo with SQLite, snapshotting `./data/forgejo` is fine —
  SQLite's WAL is consistent at any byte boundary. For Forgejo with
  Postgres, run `pg_dump` to disk before `restic backup` and include
  the dump in the source list.
- Bare-metal restore. Out of scope; restoration here is file-level.
- Encryption key escrow. The user keeps the restic password; lose it,
  the backup is unrecoverable. We tell the user to print + offline copy.
- Continuous / sub-daily backups. Default cadence is daily. Adjust the
  timer if needed; restic deduplicates so frequent runs are cheap.

## Files

| File | Purpose |
|---|---|
| `scripts/install-restic.sh` | Pin-installed restic on the source box (`--verify` mode) |
| `scripts/install-rest-server.sh` | rest-server install + systemd unit on the NAS |
| `scripts/init-repos.sh` | Interactive: NAS URL, R2 creds, password → `restic init` for both repos |
| `scripts/install-systemd-units.sh` | Drop service + timer into `/etc/systemd/system/` and enable |
| `scripts/add-source.sh <path> [tag]` | Append a source dir to the backup list |
| `scripts/run-backup.sh` | The actual backup runner (called by the timer) |
| `scripts/verify.sh` | Health check across both repos + last run |
| `scripts/restore-drill.sh` | Restore latest snapshot to scratch + git fsck |
| `systemd/restic-backup.service` | One-shot service that runs `run-backup.sh` |
| `systemd/restic-backup.timer` | Daily timer at 03:17 |
| `systemd/rest-server.service` | NAS-side append-only rest-server unit |
| `systemd/r2.env.example` | Template for R2 creds (`AWS_ACCESS_KEY_ID`, etc.) |
