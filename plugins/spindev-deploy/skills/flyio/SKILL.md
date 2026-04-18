---
name: flyio
description: Use when provisioning, deploying to, or operating fly.io machines. Trigger on any mention of flyctl, fly.toml, fly secrets, fly volumes create, fly deploy, fly launch, fly scale, fly logs, fly ssh console, cold-start tuning (min_machines_running, auto_stop_machines), region selection (iad/sjc/fra/etc), volume-migration, or Docker image builds for fly.
---

# flyio — fly.io deploy and ops

Playbook for standing up a small always-on fly.io app with volume-
backed state, managing secrets, deploying, and day-2 operations.
Decisions captured here came from the Tod deployment.

## When to use this skill

- Installing `flyctl` on a new machine.
- Creating a new fly app with a persistent volume and a deploy token.
- Building a Dockerfile targeting fly.io (pin Node / Bun LTS, install
  claude-code + plugins, small image).
- Choosing a machine size, region, and `min_machines_running` for an
  always-on workload (Telegram long-polling, webhooks, cron).
- Rotating `FLY_API_TOKEN` (deploy token), setting secrets
  (`ANTHROPIC_API_KEY`, etc.), SSH-consoling in, tailing logs.

## Decision tree

### 1. Install flyctl

One-liner from upstream:

```bash
curl -L https://fly.io/install.sh | sh
# adds ~/.fly/bin/flyctl; ensure it's on $PATH
```

Or: `scripts/install-flyctl.sh` — idempotent, `--verify` checks
version drift against upstream.

### 2. Auth

Prefer **deploy tokens** over `fly auth login` for automation and
non-interactive runs:

```bash
fly tokens create deploy --name <app>-deploy --expiry 8760h \
  > ~/.config/<project>/secrets/fly-deploy-token
chmod 600 ~/.config/<project>/secrets/fly-deploy-token
export FLY_API_TOKEN="$(cat ~/.config/<project>/secrets/fly-deploy-token)"
```

Deploy tokens are scoped to one app; a compromised token doesn't
leak access to your whole account.

### 3. Create the app + volume

```bash
fly apps create <app-name>                  # must be lowercase alnum + hyphens
fly volumes create <vol-name> \
  --app <app-name> \
  --region <region> \
  --size 3                                  # GB; grow later with `fly volumes extend`
```

Volumes are single-attach (one machine at a time). For multi-machine
apps, use one volume per machine.

### 4. Build + deploy

`fly.toml` captures app config. Minimal shape for an always-on
bot / long-running agent:

```toml
app = "<app-name>"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[[mounts]]
  source = "<vol-name>"
  destination = "/data"

[[services]]
  internal_port = 8080
  protocol = "tcp"
  auto_stop_machines = "off"        # always-on — no cold starts
  auto_start_machines = true
  min_machines_running = 1
  [[services.ports]]
    port = 80
    handlers = ["http"]
  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
```

`min_machines_running = 1` + `auto_stop_machines = "off"` is the
combo for a Telegram long-poller that must not sleep. For webhook-
based services, you can leave auto-stop on and let fly wake on
request.

Deploy:

```bash
fly deploy --app <app-name> --remote-only
```

### 5. Secrets

```bash
fly secrets set --app <app> \
  ANTHROPIC_API_KEY="sk-ant-..." \
  TELEGRAM_BOT_TOKEN="123:..." \
  GITHUB_TOKEN="github_pat_..."
```

Secrets are encrypted at rest; exposed as env vars at runtime.
Do NOT bake them into Dockerfiles or commit them to fly.toml.

### 6. Day-2 ops

```bash
fly logs --app <app>                        # tail logs
fly ssh console --app <app>                 # shell into running machine
fly status --app <app>                      # machine + volume state
fly scale count 2 --app <app>               # add machines
fly volumes snapshots create <vol-id>       # manual snapshot (recommended weekly)
fly machines restart <machine-id>           # rolling restart
```

### 7. Rotating a deploy token

```bash
fly tokens list --app <app>                 # find the old token ID
fly tokens revoke <token-id>
fly tokens create deploy --name <app>-deploy-$(date +%Y%m)
```

Store the new token, update CI / local env, revoke the old one
AFTER confirming the new one works.

## Gotchas seen in practice

- **`VAULT_*` env vars are silently stripped** at runtime. Fly reserves
  the `VAULT_` prefix for their HashiCorp Vault integration. `fly config
  show` lists your `VAULT_REPO=...` as present, `fly.toml` has it, but
  `/proc/<pid>/environ` inside the container does not. Cost us a
  silent-skipped clone and a broken first boot. Pick a different prefix
  for any env named `VAULT_...`.
- **Dockerfile PATH often excludes `/usr/sbin`** on minimal base images.
  `tailscaled` (and other sbin tools) land at `/usr/sbin/tailscaled` and
  die with `command not found` from the entrypoint. Always set
  `PATH=".../usr/local/sbin:.../usr/sbin:.../sbin:..."` in the image ENV
  or use absolute paths.
- **App name format**: lowercase alphanumeric + hyphens. Dots, caps,
  underscores rejected. `tod.smith` becomes `tod-smith`.
- **Region near user AND near API**: fly outbound to Anthropic
  (`api.anthropic.com`) is fastest from US east/west. EU regions
  add ~80 ms per turn.
- **shared-cpu-1x can throttle** during large-context assembly. If
  response latency spikes, scale to `shared-cpu-2x` / 2 GB.
- **Volume single-attach**: you cannot share one volume between two
  machines. Use per-machine volumes + git sync, or an object store.
- **Deploy token is app-scoped**: a token created for app A can't
  deploy app B. Create one per app.
- **Always-on billing**: min_machines_running=1 means ~$3.89/mo
  minimum for shared-cpu-1x. Zero-scale with auto_stop = "stop"
  saves money if cold starts are acceptable.

## Scripts

- `scripts/install-flyctl.sh` — idempotent install + verify.
- `scripts/bootstrap-app.sh <app> <region>` — create app + volume
  from a template; sets `min_machines_running=1`; prints next-step
  secret commands.
- `scripts/deploy.sh <app>` — wrapper around `fly deploy` that uses
  a stored deploy token and the local Dockerfile.

## Self-healing

Pinned versions (flyctl, base image SHA) self-heal when the
`install-flyctl.sh --verify` surfaces an upstream mismatch. Image
SHAs should be checked quarterly or on CVE reports.
