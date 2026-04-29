# restic-backup — append-only NAS + Cloudflare R2

Human-facing overview.

## What it is

A Claude skill that wires up a [restic](https://restic.net) backup
chain with two destinations:

1. **NAS via `rest-server` in append-only mode** (primary). Fast, free,
   on-LAN. Source-box credentials can write new snapshots but cannot
   delete or modify existing ones — enforced server-side.
2. **Cloudflare R2** (offsite). Write-only API token (PutObject only,
   no Delete). Optional R2 object lock for compliance-mode WORM. Zero
   egress fees on restore.

Restic is always encrypted. Same encryption key on both repos.
`restic copy` keeps dedup intact across destinations.

## Why it exists

A "backup" that an attacker (or a corrupted process on the source box)
can delete is not really a backup. The chain here gives you:

- **Ransomware resistance**: append-only NAS + write-only R2 means a
  fully-compromised source box can't destroy existing snapshots.
- **Site resistance**: R2 covers physical loss of the NAS.
- **Silent-failure resistance**: every successful run pings
  healthchecks.io; missed pings page you.
- **Untested-backup resistance**: ships a restore drill script; run it
  once after setup, quarterly thereafter.

Pairs naturally with the [`forgejo`](../forgejo/) skill — point this
chain at `./data/forgejo` and you have offsite-encrypted snapshots of
your self-hosted git server. Works equally well against any directory.

## Why these choices

- **restic** over borg: borg is fine, restic has a better
  multi-destination story (`restic copy`) and an S3-compatible backend
  for R2.
- **Cloudflare R2** over Backblaze B2: user is already on Cloudflare;
  zero egress; S3-compatible.
- **Append-only via `rest-server`** rather than filesystem perms: only
  way to get true server-side enforcement on a Linux NAS without
  per-file ACL gymnastics.
- **systemd timer** over cron: reliable logs (`journalctl -u
  restic-backup`), `OnFailure=` integration, no MAILTO surprises.

## What it does

- Installs restic on the source box (pinned to a known stable).
- Sets up `rest-server` on the NAS with `--append-only`.
- Initializes restic repos at both destinations with a shared password.
- Schedules a daily backup via systemd timer (`03:17` by default — a
  weird time so it doesn't collide with everyone-else's `0 3 * * *`).
- Runs the chain: `restic backup → NAS`, `restic copy NAS → R2`,
  prune old snapshots, ping healthchecks.io.
- Provides a restore drill that verifies backups actually work.

## Installation intent

User-level via the plugin marketplace. Auto-loads when
`spindev-deploy` is enabled.

```bash
/plugin marketplace add spinlockdevelopment/dev-setup
/plugin install spindev-deploy
```

## Entry points

- `SKILL.md` — Claude's decision tree.
- `scripts/install-restic.sh` — install restic on source.
- `scripts/install-rest-server.sh` — install rest-server on NAS.
- `scripts/init-repos.sh` — interactive setup of both repos.
- `scripts/install-systemd-units.sh` — schedule the daily run.
- `scripts/add-source.sh <path> [tag]` — add a directory.
- `scripts/run-backup.sh` — the backup runner (also runnable by hand).
- `scripts/verify.sh` — health check.
- `scripts/restore-drill.sh` — restore latest snapshot to scratch.

## Pairing

- [`forgejo`](../forgejo/) — typical primary user; back up
  `./data/forgejo` to keep the on-prem git server durable.
- Any directory — `add-source.sh /path/to/whatever projects` appends
  to the backup list.
