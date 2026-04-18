# flyio — fly.io deploy and ops

Human-facing overview.

## What it is

A decision-tree skill + helper scripts for operating on fly.io. Covers
install, app/volume provisioning, secret management, Dockerfile
patterns for an always-on agent workload, deploy, and day-2 ops
(logs, SSH, scale, snapshot, rotate).

## Why it exists

Fly.io has sensible defaults but a few gotchas that burn time on first
pass: app-name format, `min_machines_running` vs. `auto_stop_machines`
interaction for always-on bots, volume single-attach, deploy token
scope, and cold-start behavior under shared-cpu-1x. Every gotcha
section in `SKILL.md` reflects something actually stumbled on.

## What it does

- Installs `flyctl` with drift detection on upstream version.
- Creates a new app + volume with the right always-on config.
- Wraps `fly deploy` with deploy-token pickup from a chmod-600 secret
  file.
- Documents the day-2 commands (`logs`, `ssh console`, `scale`,
  `snapshots create`, token rotation).

## Installation intent

**User-level** via the plugin marketplace at
`spinlockdevelopment/dev-setup`. Auto-loads in any project that adds
the plugin.

```bash
/plugin marketplace add spinlockdevelopment/dev-setup
/plugin install spindev-deploy
```

## Entry points

- `SKILL.md` — the decision tree.
- `scripts/install-flyctl.sh` — install + `--verify`.
- `scripts/bootstrap-app.sh <app> <region>` — app + volume bring-up.
- `scripts/deploy.sh <app>` — wrapper around `fly deploy`.

All scripts support `--verify` where it makes sense.
