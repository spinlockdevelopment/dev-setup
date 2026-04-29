# forgejo — self-hosted backup git server

Human-facing overview.

## What it is

A Claude skill that brings up [Forgejo](https://forgejo.org/) — the
community-governed soft-fork of Gitea — in Docker as a self-hosted git
server. Two roles:

1. **Pull-mirror for GitHub repos.** Public/work repos stay canonical
   on GitHub; Forgejo fetches them on a schedule as a read shadow.
2. **Canonical home for on-prem-only repos.** Sensitive projects that
   shouldn't touch GitHub at all push directly to Forgejo.

Both roles share the same data dir, which the [`restic-backup`](../restic-backup/)
skill snapshots to a NAS (append-only) and Cloudflare R2 (offsite,
write-only credentials).

## Why it exists

GitHub is reliable, but "the only copy of my source lives on a SaaS I
don't control" is a brittle position. A force-push, a leaked PAT with
delete scope, a billing dispute, a takedown — all of these can
silently or loudly remove history. A second place that fails
differently is cheap insurance.

Forgejo specifically (over Gitea, GitBucket, GitLab CE):
- **Forgejo** is the actively-maintained community fork; lighter than
  GitLab; better governance trajectory than Gitea. First-class pull-mirror.
- **Gitea** functionally works but the governance fork is why Forgejo exists.
- **GitBucket** is alive but minimally maintained; JVM weight isn't worth it.
- **GitLab CE** is overkill for "second place to push my code".

## What it does

- Stands up Forgejo in Docker via `docker compose`, persistent volume
  at `./data/forgejo`.
- Pinned to **Forgejo LTS** (currently v15.0.1, supported through
  2027-07-15). Self-heals when LTS rolls.
- Configures pull-mirroring from GitHub via the Forgejo API, with
  branch protection so the mirror can't be force-pushed or deleted
  by any client (including the API used to create it).
- Provides direct-push workflow for on-prem-only repos.
- Health-check script that warns when mirrors stop syncing.

## Installation intent

User-level via the plugin marketplace at
`spinlockdevelopment/dev-setup`. Auto-loads when `spindev-deploy` is
enabled.

```bash
/plugin marketplace add spinlockdevelopment/dev-setup
/plugin install spindev-deploy
```

## Entry points

- `SKILL.md` — Claude's decision tree.
- `scripts/bootstrap.sh <hostname>` — first-time bringup.
- `scripts/add-mirror.sh <github-url> [interval]` — add a pull-mirror.
- `scripts/create-repo.sh <name> [--private]` — create an on-prem-only repo.
- `scripts/verify.sh` — health check.

## Pairing

Use with [`restic-backup`](../restic-backup/) — it points at
`./data/forgejo` and ships nightly snapshots to a NAS (append-only via
`rest-server`) and Cloudflare R2 (write-only API token). That's the
durability story; Forgejo alone is just a second copy, not a backup.
