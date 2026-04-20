# Claude skills index

Authoritative catalog of every skill in this repo. Update this file whenever
a skill is added, removed, or materially changed.

## How skills ship

This repo is a Claude Code **plugin marketplace**. Skills are grouped into
three plugins published from `.claude-plugin/marketplace.json`:

| Plugin | Skills |
|---|---|
| `spindev-core` | `end-session`, `init-project`, `review-plan` |
| `spindev-devenv` | `create-gh-token`, `hardened-shell`, `my-status-line`, `ubuntu-debloat` |
| `spindev-deploy` | `sprites-dev` |

Consumer projects enable whichever plugins they need from
`.claude/settings.json`. See [`README.md`](./README.md) for the snippet.

## Plugins

### `spindev-core`

Path: `plugins/spindev-core/`
Manifest: [`.claude-plugin/plugin.json`](./plugins/spindev-core/.claude-plugin/plugin.json)
Slash commands: `/end-session`, `/init-project`, `/review-plan`

Session / project-lifecycle primitives. Enable on every project.

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

Deployment-target reference skills. Enable only on projects that
actually deploy to the matching platform.

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

Targets: any host that drives sprites.dev; especially Windows/Git Bash.
