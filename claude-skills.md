# Claude skills index

Authoritative catalog of every skill in this repo. Update this file whenever
a skill is added, removed, or materially changed.

## How skills ship

This repo publishes the same skills through a Codex CLI marketplace,
Claude Code marketplace, and Gemini CLI extension collection. Skills are
grouped into three plugins published from
`.agents/plugins/marketplace.json`, `.claude-plugin/marketplace.json`,
and each plugin's `gemini-extension.json`:

| Plugin | Skills | Subagents | Hooks |
|---|---|---|---|
| `spindev-core` | `end-session`, `gh`, `init-project`, `review-plan` | `pr-prepass` | gh-workflow advisory (PreToolUse Bash) |
| `spindev-devenv` | `create-gh-token`, `hardened-shell`, `my-status-line`, `ubuntu-debloat` | — | — |
| `spindev-deploy` | `flyio`, `forgejo`, `restic-backup`, `sprites-dev` | — | sprite-guard, fly-guard (PreToolUse Bash) |
| `spindev-docs` | `technical-writer` | `technical-writer` | — |

Consumer projects enable whichever plugins they need for their target
agent. See [`README.md`](./README.md) for install details.

## Plugins

### `spindev-core`

Path: `plugins/spindev-core/`
Manifest: [`.claude-plugin/plugin.json`](./plugins/spindev-core/.claude-plugin/plugin.json)
Codex manifest: [`.codex-plugin/plugin.json`](./plugins/spindev-core/.codex-plugin/plugin.json)
Slash commands: `/end-session`, `/init-project`, `/pr-prepass`, `/review-plan`
Subagents: `pr-prepass`
Hooks: `gh-workflow` (non-blocking PreToolUse advisory on `gh`/`git push` patterns)

Session / project-lifecycle primitives. Enable on every project.

#### `pr-prepass` (subagent)

Path: `plugins/spindev-core/agents/pr-prepass.md`
Entry points:
- `/pr-prepass` (slash command — dispatches the subagent)
- Auto-dispatched from `/end-session` step 11 when `.github/workflows/pr-review.yml` exists

Mirrors the repo's PR auto-review CI locally before push so the
operator can fix findings without burning a CI cycle and without
rebroadcasting findings on a public PR. Reads
`.github/workflows/pr-review.yml` at runtime to get the authoritative
list of CI steps; mirrors gitleaks + shellcheck + script-convention
checks + a Claude PII/secrets/structural pass over the current
branch's diff vs the default branch. Returns a structured findings
report in the same shape as the CI summary. Verdict: `safe to push`,
`fix findings before pushing`, or `not applicable` if no
`pr-review.yml`. Does not push, does not open the PR — reports only.
Lifted from `agent.smith` after the pattern proved out.

#### `end-session`

Path: `plugins/spindev-core/skills/end-session/`
Human guide: [`README.md`](./plugins/spindev-core/skills/end-session/README.md)
Entry point: `SKILL.md` (triggered by `/end-session` or wrap-up phrases)

Wraps up a working session so a following `/clear` loses nothing
important. Detects bringup vs protected project mode, syncs docs
(`CLAUDE.md`, indexes, plans), reconciles TODOs, prunes stale memory,
runs local quality gates (tests/typecheck/lint), appends to
`SESSION-SUMMARIES.md`, syncs with `origin` to avoid orphaned-commit
confusion from squash merges, and — when work is clearly complete —
pushes a feature branch with PR + auto-merge + squash. Worktree-aware.
Asks before any destructive git op. Self-improves in place.

#### `gh`

Path: `plugins/spindev-core/skills/gh/`
Entry point: `SKILL.md` (triggered by mentions of GitHub org setup, fine-grained PAT creation, repo creation, branch protection, rulesets, or the "Resource not accessible by personal access token" 403)

Decision-tree playbook for provisioning and managing GitHub orgs,
fine-grained PATs, and branch protection. Captures the
often-missed detail that `POST /orgs/{org}/repos` requires
**Repository → Administration: Read and write**, not Organization
Administration. Also covers the legacy-branch-protection-vs-rulesets
choice (rulesets only available on Team plan and above for private
org repos), the org-level ruleset that protects
`main`/`staging`/`prod` across every repo with no bypass actors, and
the 403-triage flow when a PAT hits "Resource not accessible by
personal access token". Scripts: `bootstrap-pat.sh`,
`create-repo.sh`, `apply-org-ruleset.sh`, `probe-token.sh`.

#### `init-project`

Path: `plugins/spindev-core/skills/init-project/`
Human guide: [`README.md`](./plugins/spindev-core/skills/init-project/README.md)
Entry point: `SKILL.md` (triggered by `/init-project` or phrases like "initialize this project", "set up this repo for Claude", "bring this project up to baseline")

Repeat-safe baseline-setup skill. Ensures the project is a git repo on
`main`; detects bringup vs protected mode using the same heuristic as
`end-session` (feature branches, squash-merge history, optional `gh api`
branch-protection probe) and writes or removes the `## Project Mode`
breadcrumb in `CLAUDE.md`; scaffolds a minimal `CLAUDE.md` and `README.md`
if either is missing (asking the user only for details it can't infer
from manifest files); idempotently stamps a canonical **Pull Request
Workflow** rules block into `CLAUDE.md` bracketed by HTML comment markers
so re-runs update in place rather than duplicate; auto-junctions
dev-setup-owned dependency skills (`end-session`, `review-plan`) into
`~/.claude/skills/`; and reports plugin-sourced skills (`simplify`,
`codex`, `superpowers`, `claude-md-management`) that are missing with
the exact install command. Self-improves in place.

#### `review-plan`

Path: `plugins/spindev-core/skills/review-plan/`
Human guide: [`README.md`](./plugins/spindev-core/skills/review-plan/README.md)
Entry point: `SKILL.md` (triggered by `/review-plan` or phrases like "review the plan", "harden the plan", "add checkpoints to the plan")

Pre-implementation hardening pass for plans produced by
`superpowers:writing-plans`. Runs a simplification review (inline,
DRY/YAGNI/scope lens) plus an adversarial cross-model review
(`/codex:adversarial-review`) over the plan document, lets the user
triage findings, applies accepted edits, and — for long plans (6+
tasks) — injects explicit `### Checkpoint` blocks at logical
subsystem/layer/dependency breaks. Short plans (≤5 tasks) skip
checkpoint injection. Detects parallel-track plans and offers a
worktree-per-track execution model so commits do not interleave and
per-track `/codex:review --scope branch` stays clean. The injected
checkpoint blocks dispatch both `superpowers:code-reviewer` (same-model)
and `/codex:review` (cross-model) at each batch. After the skill runs,
the user says "continue with implementation" and normal execution
(`executing-plans` recommended) picks up, honoring the checkpoint blocks
natively.

### `spindev-devenv`

Path: `plugins/spindev-devenv/`
Manifest: [`.claude-plugin/plugin.json`](./plugins/spindev-devenv/.claude-plugin/plugin.json)
Codex manifest: [`.codex-plugin/plugin.json`](./plugins/spindev-devenv/.codex-plugin/plugin.json)
Slash commands: `/create-gh-token`

Developer-machine setup + sandboxed execution. Enable on boxes where you
actually bring up dev environments or run banshee-mode agents. Skip on
Claude Code Web sandboxes.

#### `create-gh-token`

Path: `plugins/spindev-devenv/skills/create-gh-token/`
Human guide: [`README.md`](./plugins/spindev-devenv/skills/create-gh-token/README.md)
Entry points:
- `SKILL.md` (triggered by `/create-gh-token` or phrases like "set up a github token", "create a PAT for this project", "wire a github token into this project", "let claude push from this repo")
- `scripts/create-gh-token.sh` — paste, validate, wire into git remote

Mints a fine-grained GitHub Personal Access Token tailored to one
project, then wires it into the project's HTTPS git remote so pushes
work without a credential prompt. Question-driven: Claude asks four
short questions (should the token create repos? org-wide or single
repo? which sub-permissions: Issues / PRs / Workflows / Actions /
Pages? branch-protection plan?), prints a concise tuned checklist
for the GitHub PAT-creation form, then runs the script. The script
parses `<owner>/<repo>` from `origin`, prompts silently for the
pasted token, validates it against `/user` and the specific repo's
endpoint, and rewrites the remote URL to embed the token via
`x-access-token`. Token lives only in `.git/config` (local, never
pushed). `--verify` mode probes an already-wired remote;
`--no-set-remote` validates without touching `.git/config`. The
README is self-contained — a permission-by-permission reference plus
an inline org-ruleset / per-repo-protection guide so a user reading
just that file can mint and wire the token themselves.

Targets: any project with a github.com remote (HTTPS or SSH; SSH is
auto-converted on rewrite).

#### `ubuntu-debloat`

Path: `plugins/spindev-devenv/skills/ubuntu-debloat/`
Human guide: [`README.md`](./plugins/spindev-devenv/skills/ubuntu-debloat/README.md)
Entry point: `scripts/run-all.sh` (or `scripts/run-all.sh --verify`)

Debloats a fresh Ubuntu desktop install and sets it up for Claude Code
and development. Removes games, office apps, Firefox, and snapd (with an
apt pin to keep it out). Installs Chrome (amd64) and Brave (amd64 +
arm64) for browser coverage, plus Docker CE, mise-managed
Python/Node/Go/JDK, Android Studio, and VS Code from native upstream
repos. Enables unattended-upgrades and `ufw`. Ships idempotent scripts
with a `--verify` mode and self-heals on upstream version drift (via
`scripts/check-versions.sh`).

Targets: Ubuntu 24.04+ desktop. Latest LTS / public-GA only.

#### `my-status-line`

Path: `plugins/spindev-devenv/skills/my-status-line/`
Human guide: [`README.md`](./plugins/spindev-devenv/skills/my-status-line/README.md)
Entry point: `scripts/install.sh` (or `scripts/install.sh --verify`, `scripts/uninstall.sh`)
Slash command: `/my-status-line`

Installs a compact Claude Code status line:
`foldername | gitbranch | sandbox | ctx Nk (P%) | Model`. Copies a
helper script to `~/.claude/statusline.sh` (stable path that survives
plugin-cache version bumps) and wires `statusLine` into
`~/.claude/settings.json`. Segments drop out when not applicable (no
git repo → no branch; `$HSHELL != 1` → no sandbox marker). Max
context is 1M for model ids ending in `[1m]`, else 200k. Tokens are
parsed from the transcript JSONL (`input + cache_read +
cache_creation` of the last assistant turn). Idempotent install;
`--verify` mode for read-only health check. Uses Python 3 for JSON
parsing — portable across Linux / macOS / Windows Git Bash without
needing `jq`.

#### `hardened-shell`

Path: `plugins/spindev-devenv/skills/hardened-shell/`
Human overview: [`README.md`](./plugins/spindev-devenv/skills/hardened-shell/README.md)
Deep user guide: [`USAGE.md`](./plugins/spindev-devenv/skills/hardened-shell/USAGE.md)
Entry points:
- `scripts/build-image.sh` — build `hshell:latest`
- `scripts/install.sh` — symlink `hshell` into `~/.local/bin`
- `scripts/verify.sh` — health check

Ships `hshell`, a launcher that drops into a hardened Docker sandbox so
Claude (and other agents) can run with `--dangerously-skip-permissions`
without risking the host. Host is bind-mounted read-only at `/host` with
a credential blocklist masking `.ssh`/`.aws`/`.gnupg`/`.netrc`/browser
profiles/etc. `$PWD` is the agent's only writable world at `/work`.
Per-project Claude state persists in `$PWD/.internal/claude/`. Subagents
share `/work` and coordinate via git worktrees under `/work/.worktree/`.

Image is Debian slim with mise-pinned Node + Python LTS, `claude-code`,
and common dev CLIs. Pins self-heal on LTS rollover (see SKILL.md).

Targets: any host with Docker CE. Latest LTS / public-GA only.

### `spindev-deploy`

Path: `plugins/spindev-deploy/`
Manifest: [`.claude-plugin/plugin.json`](./plugins/spindev-deploy/.claude-plugin/plugin.json)
Codex manifest: [`.codex-plugin/plugin.json`](./plugins/spindev-deploy/.codex-plugin/plugin.json)
Hooks: `sprite-guard`, `fly-guard` (PreToolUse Bash)

Deployment-target reference skills. Enable only on projects that
actually deploy to the matching platform.

#### `flyio`

Path: `plugins/spindev-deploy/skills/flyio/`
Entry point: `SKILL.md` (triggered by `flyctl`, `fly.toml`, `fly secrets`, `fly volumes`, `fly deploy`, region selection, cold-start tuning, `min_machines_running`, or volume-migration questions)

Playbook for standing up a small always-on fly.io app with
volume-backed state, managing secrets, deploying, and day-2 ops.
Decisions came from the Tod deployment. Covers flyctl install,
deploy-token auth (preferred over `fly auth login` for automation),
app + single-attach volume creation, the `fly.toml` shape for an
always-on long-poller (`min_machines_running=1`,
`auto_stop_machines="off"`), secrets, ssh-console access, and token
rotation. Documents real-world gotchas: `VAULT_*` env vars are
silently stripped, Dockerfile PATH often excludes `/usr/sbin` (kills
`tailscaled`), app names are lowercase alphanumeric + hyphens only,
shared-cpu-1x can throttle during large-context assembly, and
deploy tokens are app-scoped.

Backstop hook: `fly-guard` (`hooks/scripts/fly-guard.sh`) catches
`fly apps/volumes/machines destroy` without `--yes`,
`fly secrets set VAULT_*` (silently stripped), and bad
`fly apps create` names; advisory on `fly deploy` without
`--remote-only`.

Targets: any host with `flyctl` installed and a fly.io account.

#### `sprites-dev`

Path: `plugins/spindev-deploy/skills/sprites-dev/`
Human guide: [`README.md`](./plugins/spindev-deploy/skills/sprites-dev/README.md)
Entry point: `SKILL.md` (triggered by any mention of `sprite` CLI, sprites.dev API, `sprite exec`, `sprite api`, uploading into a sprite)

Correct-usage reference for the `sprite` CLI and sprites.dev API on
Windows / Git Bash. Every rule in the skill traces to an actual failure
seen in a project: Git Bash silently rewrites Unix-looking paths before
`sprite` sees them, breaking `sprite exec` flag parsing, `sprite api`
URLs, `--file` source:dest uploads, and `--dir`. The skill codifies the
`bash -c` wrapping pattern, the `MSYS_NO_PATHCONV=1` prefix for API
calls, the `sprite api <path> -- <curl-flags>` ordering, and the
compress-before-upload workaround for files over ~20 MB that otherwise
hit HTTP 502.

Backstop hook: `sprite-guard` (`hooks/scripts/sprite-guard.sh`)
enforces rules 1, 2, 3, and 6 at execution time and blocks the call
with an explanatory message if a `sprite` invocation violates them.

Targets: any host that drives sprites.dev; especially Windows/Git Bash.

#### `forgejo`

Path: `plugins/spindev-deploy/skills/forgejo/`
Human overview: [`README.md`](./plugins/spindev-deploy/skills/forgejo/README.md)
Entry point: `SKILL.md` (triggered by self-hosting git, mirroring GitHub, "second copy" / backup of source, Forgejo, Gitea, GitBucket, codeberg-style hosting, on-prem git, pull-mirror, escaping GitHub-only durability)

Stands up [Forgejo](https://forgejo.org/) (the community soft-fork of
Gitea) in Docker as a self-hosted git server with two roles: pull-mirror
for GitHub-canonical repos and direct-push canonical home for on-prem-only
sensitive repos. Uses Forgejo's first-class pull-mirror with non-force
fetch semantics — if upstream is force-pushed, the next sync errors
instead of overwriting. Auto-applies branch protection (`enable_push:
false`, `enable_force_push: false`) on mirrored repos so nothing
client-side can rewrite history. SQLite storage; single data dir at
`./data/forgejo` is what the `restic-backup` skill snapshots.

Pinned to Forgejo LTS (currently v15.0.1, supported through 2027-07-15).
Targets: any Linux host running Docker.

#### `restic-backup`

Path: `plugins/spindev-deploy/skills/restic-backup/`
Human overview: [`README.md`](./plugins/spindev-deploy/skills/restic-backup/README.md)
Entry point: `SKILL.md` (triggered by backups, restic, borg, append-only,
write-only credentials, NAS share, Cloudflare R2 / S3 / object storage
backup, healthchecks.io, restore drills, ransomware-resistant backup,
"second copy of source", or pairing with `forgejo` to back up its data dir)

Wires up an encrypted two-destination restic chain: append-only NAS via
`rest-server` (primary, fast, free) + Cloudflare R2 with write-only API
credentials (offsite, immutable). The source box only writes — never
deletes — so leaked source-box creds cannot destroy existing snapshots.
Retention is decoupled into `prune-on-nas.sh`, run from the NAS itself
with elevated creds. Pings healthchecks.io on each successful run so
silent backup failure surfaces as a missed-ping alert. Ships a
`restore-drill.sh` that pulls latest snapshots into a scratch dir and
runs `git fsck` against any bare repos found, since untested backups
aren't backups.

Pinned to restic 0.18.1 + rest-server v0.14.0. Pairs naturally with the
`forgejo` skill but works against any directory. Targets: a Linux source
box, a Linux NAS for `rest-server`, and a Cloudflare R2 bucket.

### `spindev-docs`

Path: `plugins/spindev-docs/`
Manifest: [`.claude-plugin/plugin.json`](./plugins/spindev-docs/.claude-plugin/plugin.json)
Codex manifest: [`.codex-plugin/plugin.json`](./plugins/spindev-docs/.codex-plugin/plugin.json)
Slash commands: `/technical-writer`, `/docs-deploy`
Subagents: `technical-writer`

Documentation skills. Enable on projects that want a maintained design
doc (mkdocs-material site, GitHub Pages-ready).

#### `technical-writer` (skill + subagent)

Path: `plugins/spindev-docs/skills/technical-writer/`
Subagent: `plugins/spindev-docs/agents/technical-writer.md`
Human overview: [`README.md`](./plugins/spindev-docs/skills/technical-writer/README.md)
Deep user guide: [`USAGE.md`](./plugins/spindev-docs/skills/technical-writer/USAGE.md)
Entry points:
- `/technical-writer` (Claude / Gemini slash command — dispatches the subagent on Claude, runs the skill body on Gemini)
- `scripts/run-all.sh` — orchestrator (also `--verify`, `--full-regen`)
- `scripts/deploy-gh-pages.sh` — scaffold GH Pages workflow (also via `/docs-deploy`)

Scans an entire repository and publishes a coherent mkdocs-formatted
design doc (mkdocs-material theme, GitHub Pages-ready). **Delta-aware
on rerun**: consults a per-repo state file at
`~/.local/state/technical-writer/repos/<key>.json` and either
incrementally updates only the pages whose source files changed, or
full-regenerates if the delta is too disruptive (rebase / force-push /
branch swap detected via `git merge-base --is-ancestor`, or breadth/depth
too large for clean merge — the LLM, not a hardcoded threshold,
decides). The page menu is adaptive: `architecture.md`,
`components.md`, `data-flow.md`, `deployment.md`, `operations.md`,
`development.md`, `glossary.md` are materialized only when the scan
finds the corresponding source surface; empty stubs are dropped from
`nav:` too. Pre-publish secrets/PII pass on each generated page mirrors
the Claude pass in `pr-prepass` — blocks on findings rather than
silently redacting. Output is plain mkdocs — portable to Cloudflare
Pages, Netlify, or any static host that consumes `site/`. Refuses to
overwrite an existing non-mkdocs `docs/` (writes to `design-docs/`
instead and configures `docs_dir: design-docs` in `mkdocs.yml`).
mkdocs + mkdocs-material install via pipx on first run; preflight
prints the `! sudo apt install -y pipx` line for the operator if
pipx itself is missing.

`/docs-deploy` is a separate command that scaffolds
`.github/workflows/deploy-mkdocs.yml` (modern split:
`actions/upload-pages-artifact@v3` + `actions/deploy-pages@v4`; no
`gh-pages` branch). Generation and publication are decoupled —
write/refresh on every meaningful commit, deploy when ready.

Targets: any host with `git` + `pipx` (or `mkdocs` already on PATH).
Latest LTS / public-GA only.
