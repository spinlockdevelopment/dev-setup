# Components

Each plugin in `plugins/` is a standalone unit. Below is a per-plugin
walkthrough of what it ships, why it exists, and how its parts fit
together.

## `spindev-core` — workflow primitives

Path: [`plugins/spindev-core/`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-core)

The smallest plugin a project should install. Skills here run on most
projects regardless of language or deployment target.

### Skills

| Skill | Entry | What it does |
|---|---|---|
| [`end-session`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-core/skills/end-session) | `/end-session` | Wraps up a working session: detects bringup vs protected mode, syncs docs (`CLAUDE.md`, indexes, plans), reconciles TODOs, prunes stale memory, runs local quality gates, appends to `SESSION-SUMMARIES.md`, syncs with `origin`, and (when complete) pushes a feature branch with PR + auto-merge + squash. Worktree-aware. Asks before any destructive git op. |
| [`init-project`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-core/skills/init-project) | `/init-project` | Repeat-safe baseline: ensures the project is a git repo on `main`, detects mode, scaffolds minimal `CLAUDE.md`/`README.md`, stamps a canonical Pull Request Workflow rules block bracketed by HTML comment markers (so re-runs update in place instead of duplicating), and reports missing dependency skills. |
| [`gh`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-core/skills/gh) | `SKILL.md` triggered by GitHub-related questions | Decision-tree playbook for org provisioning, fine-grained PATs, and branch protection. Captures the often-missed detail that `POST /orgs/{org}/repos` requires Repository → Administration: Read+Write, not Organization Administration. Includes scripts for `bootstrap-pat.sh`, `create-repo.sh`, `apply-org-ruleset.sh`, `probe-token.sh`. |
| [`review-plan`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-core/skills/review-plan) | `/review-plan` | Pre-implementation hardening for plans produced by `superpowers:writing-plans`. Runs an inline simplification review plus an adversarial cross-model review via `/codex:adversarial-review`, applies accepted edits, and (for plans of 6+ tasks) injects `### Checkpoint` blocks at logical subsystem/layer/dependency breaks rather than at fixed intervals. |

### Subagents

- **[`pr-prepass`](https://github.com/spinlockdevelopment/dev-setup/blob/main/plugins/spindev-core/agents/pr-prepass.md)** — local mirror of a repo's PR auto-review CI workflow. Reads `.github/workflows/pr-review.yml` at runtime to discover the authoritative check list (gitleaks, shellcheck, script conventions, a Claude PII/secrets/structural pass), runs each locally against the current branch's diff, and reports findings in the same shape as the CI summary. Does not push or open the PR — reports only. Auto-dispatched from `/end-session` when a `pr-review.yml` exists.

### Hooks

- **`gh-workflow`** — non-blocking PreToolUse Bash advisory that warns
  on `gh repo create` without `--template`, `gh pr merge` without an
  explicit strategy, `git push` to protected branches (main/master/staging/prod),
  and force-push to protected branches. Trial through 2026-05-13;
  re-evaluate for blocking promotion or removal at that date.

### Slash commands

`/end-session`, `/init-project`, `/pr-prepass`, `/review-plan` (Claude
`.md` and Gemini `.toml` for each).

## `spindev-devenv` — developer-machine setup

Path: [`plugins/spindev-devenv/`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-devenv)

Skills the operator runs on a developer box itself, not inside a
project. Skip on Claude Code Web sandboxes — these are for boxes
where you actually bring up dev environments or run banshee-mode
agents.

### Skills

| Skill | Entry | What it does |
|---|---|---|
| [`create-gh-token`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-devenv/skills/create-gh-token) | `/create-gh-token` or `scripts/create-gh-token.sh` | Mints a fine-grained GitHub PAT tailored to a single project and wires it into the project's HTTPS git remote via `x-access-token`. Question-driven: four short questions tune the permission checklist. The token never leaves `.git/config` (local, never pushed). `--verify` mode probes an already-wired remote. |
| [`hardened-shell`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-devenv/skills/hardened-shell) | `scripts/build-image.sh`, `scripts/install.sh` | Ships `hshell`, a launcher that drops into a hardened Docker sandbox so Claude can run with `--dangerously-skip-permissions` without risking the host. Host bind-mounted read-only at `/host` with a credential blocklist. `$PWD` is the agent's only writable surface at `/work`. Per-project state persists in `$PWD/.internal/claude/`. |
| [`my-status-line`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-devenv/skills/my-status-line) | `/my-status-line` or `scripts/install.sh` | Installs a compact Claude Code status line: `foldername \| gitbranch \| sandbox \| ctx Nk (P%) \| Model`. Copies a helper to `~/.claude/statusline.sh` (stable path that survives plugin-cache version bumps). Tokens parsed from the transcript JSONL. |
| [`ubuntu-debloat`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-devenv/skills/ubuntu-debloat) | `scripts/run-all.sh` (or `--verify`) | Debloats a fresh Ubuntu desktop install and brings it up for development. Removes games, office apps, Firefox, snapd (with an apt pin to keep snapd out). Installs Chrome, Brave, Docker CE, mise-managed Python/Node/Go/JDK, Android Studio, and VS Code from native upstream repos. Idempotent scripts in numbered phases, shared `lib.sh`. |

### Slash commands

`/create-gh-token`, `/my-status-line` (Claude `.md` and Gemini
`.toml`).

## `spindev-deploy` — deployment-target references

Path: [`plugins/spindev-deploy/`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-deploy)

Reference skills for specific deployment targets and on-prem
infrastructure. Enable only on projects that actually deploy to the
matching platform; the dependency surface is non-trivial.

### Skills

| Skill | Entry | What it does |
|---|---|---|
| [`flyio`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-deploy/skills/flyio) | `SKILL.md` triggered by `flyctl`/`fly.toml`/`fly secrets`/etc. | Playbook for standing up a small always-on fly.io app with volume-backed state and managing day-2 ops. Documents real gotchas: `VAULT_*` env vars are silently stripped, Dockerfile PATH often excludes `/usr/sbin` (kills `tailscaled`), app names are lowercase alphanumeric + hyphens only, deploy tokens are app-scoped. |
| [`forgejo`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-deploy/skills/forgejo) | `SKILL.md` triggered by self-hosted git, mirroring GitHub, etc. | Stands up Forgejo (community soft-fork of Gitea) in Docker as a self-hosted git server with two roles: pull-mirror for GitHub-canonical repos, and direct-push canonical home for on-prem-only sensitive repos. Auto-applies branch protection on mirrored repos so nothing client-side can rewrite history. SQLite storage, single data dir at `./data/forgejo`. |
| [`restic-backup`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-deploy/skills/restic-backup) | `SKILL.md` triggered by backups, restic, append-only, R2, etc. | Wires up an encrypted two-destination restic chain: append-only NAS via `rest-server` (primary, fast, free) + Cloudflare R2 with write-only API credentials (offsite, immutable). The source box only writes — never deletes — so leaked source-box creds cannot destroy existing snapshots. Pings healthchecks.io on success; ships a restore-drill script that runs `git fsck` against any bare repos found. Pinned to restic 0.18.1 + rest-server v0.14.0. |
| [`sprites-dev`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-deploy/skills/sprites-dev) | `SKILL.md` triggered by sprite CLI, sprites.dev API | Correct-usage reference for the `sprite` CLI on Windows / Git Bash. Every rule traces to a real failure: Git Bash silently rewrites Unix-looking paths before `sprite` sees them, breaking `sprite exec`, `sprite api`, and `--file` source:dest uploads. Codifies the `bash -c` wrapping pattern, the `MSYS_NO_PATHCONV=1` prefix, and the compress-before-upload workaround for files over ~20 MB. |

### Hooks

- **`fly-guard`** — PreToolUse Bash. **Blocks** destructive `fly`
  ops (`destroy`, `token revoke`) without `--yes`, `fly secrets set
  VAULT_*` (silently stripped), and invalid app names. Advises on
  `fly deploy` without `--remote-only`.
- **`sprite-guard`** — PreToolUse Bash. **Blocks** `sprite exec`
  without bash -c wrapper, `sprite api /path` on Windows without
  `MSYS_NO_PATHCONV=1`, bad flag ordering, and `--dir` absolute
  paths on Git Bash.

Both hooks are paired with a "Backstop hook" section in the partner
skill's SKILL.md so the matchers and the rules stay in sync.

## `spindev-docs` — documentation generation

Path: [`plugins/spindev-docs/`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-docs)

The newest plugin. Generates the design doc you are reading right
now.

### Skill + subagent

- **[`technical-writer`](https://github.com/spinlockdevelopment/dev-setup/tree/main/plugins/spindev-docs/skills/technical-writer)**
  — scans an entire repo and publishes a coherent mkdocs-formatted
  design doc with the mkdocs-material theme. **Delta-aware** on
  rerun: consults a per-repo state file at
  `~/.local/state/technical-writer/repos/<key>.json` and either
  incrementally updates only the pages whose source files changed,
  or full-regenerates if the delta is too disruptive (rebase /
  force-push / branch swap detected, or breadth/depth too large for
  clean merge — the LLM, not a hardcoded threshold, decides). The
  page menu is adaptive: `architecture.md`, `components.md`,
  `data-flow.md`, `deployment.md`, `operations.md`, `development.md`,
  `glossary.md` are materialized only when the scan finds the
  corresponding source surface; empty stubs are dropped from `nav:`
  too. Pre-publish secrets/PII pass on each generated page mirrors
  the Claude pass in `pr-prepass`.

The Claude subagent at
[`agents/technical-writer.md`](https://github.com/spinlockdevelopment/dev-setup/blob/main/plugins/spindev-docs/agents/technical-writer.md)
wraps the skill with a procedural prompt that handles the workflow
phases. Codex and Gemini run the skill body directly without a
subagent layer.

### Slash commands

- `/technical-writer` — generate or refresh the design doc.
- `/docs-deploy` — scaffold an opt-in `.github/workflows/deploy-mkdocs.yml`
  using the modern `actions/upload-pages-artifact@v3` +
  `actions/deploy-pages@v4` flow (no `gh-pages` branch).

Output is plain mkdocs `site/` — portable to GitHub Pages, Cloudflare
Pages, Netlify, or any static host that consumes a built directory.
mkdocs and `mkdocs-material` install via `pipx` on first run.

## How the plugins relate

There is intentionally no cross-plugin import or shared library. Each
plugin can be installed and uninstalled independently. The pairings
that exist are documented in the relevant SKILL.md files:

- `forgejo` (self-hosted git) ↔ `restic-backup` (back up
  `./data/forgejo`).
- `init-project` (baseline) → `technical-writer` (design doc).
- `end-session` → `pr-prepass` (auto-dispatched when
  `.github/workflows/pr-review.yml` exists).
- `review-plan` (pre-implementation hardening) → `executing-plans`
  (handover to plan execution).
