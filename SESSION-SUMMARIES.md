# Session summaries

Append-only log of what each session accomplished. One entry per session,
newest at the bottom. Read the latest entry before resuming work in this
repo to avoid re-deriving context.

## 2026-04-16 — main

- Moved the `end-session` skill from `~/.claude/skills/end-session/` into
  this repo at `.claude/skills/end-session/` (SKILL.md + README.md) so it
  lives in git, then exposed it user-wide via a Windows directory
  junction (`mklink /J`).
- Discovered that Git Bash `ln -s` silently *copies* directories on this
  Windows host instead of linking — produced a duplicate skill listing
  before being caught. Cleaned up and used `mklink /J` (works without
  admin/developer mode). Documented the workaround in the install
  section of `claude-skills.md`.
- Added an `end-session` entry to `claude-skills.md` and a `## Project
  Mode` breadcrumb (bringup) plus a `SESSION-SUMMARIES.md` reference to
  `CLAUDE.md`.
- No tests / lint in this repo yet; quality gates skipped.

Future-you notes:
- The `ln -s` example in `claude-skills.md` is Linux/macOS only. On
  Windows, always use the `mklink /J` form documented right below it.
  Verify links with `cmd //c dir <parent>` — a real link shows
  `<JUNCTION>` (or `<SYMLINKD>`), not `<DIR>`.
- Bringup mode breadcrumb is in `CLAUDE.md`. Remove it the first time a
  feature branch + PR lands and switch wrap-up behavior to protected.

## 2026-04-16 — main (review-plan skill)

- Added new skill `.claude/skills/review-plan/` — pre-implementation
  hardening pass on superpowers plans. Runs a DRY/YAGNI/scope-lens
  simplification review (inline) plus an adversarial cross-model review
  (`/codex:adversarial-review`) over the plan doc, lets the user triage
  findings, applies accepted edits, then injects `### Checkpoint` blocks
  at **logical** subsystem/layer/dependency breaks (not fixed
  intervals). Short plans (≤5 tasks) skip checkpoint injection.
- Checkpoint blocks dispatch both `superpowers:code-reviewer` (same
  model) and `/codex:review` (cross model) per batch — so long plans
  get cross-model review at logical boundaries instead of per-task
  noise.
- Supports parallel-track plans: detects `## Track:` headings or
  non-overlapping domain clusters, offers the user a parallel path via
  `superpowers:using-git-worktrees` + `superpowers:dispatching-parallel-agents`.
  Each track runs in its own worktree (local-only, merged back to the
  feature branch) so per-track `/codex:review --scope branch` never
  picks up commits from other tracks.
- Skill body is a thin decision tree; injected markdown lives in
  `assets/` (`checkpoint-template.md`, `plan-header-note.md`,
  `parallel-tracks-note.md`) per the repo's "skill SKILL.md stays thin"
  convention.
- `claude-skills.md` index updated with the entry.
- No tests/lint; quality gates skipped.

Future-you notes:
- Skill is auto-loaded inside this repo. To use it in another project,
  junction it in the same way as `end-session` (see `claude-skills.md`).
- `review-plan` expects codex to be installed (provides `/codex:review`
  and `/codex:adversarial-review`). If codex is not present, the skill
  stops and says so before doing any work.
- Best way to validate the skill is a real run on a freshly generated
  plan. Rough edges to watch for on first use:
  the commit-the-plan step (step 3) when the worktree already has
  unrelated changes; codex output length overwhelming step 6 triage;
  threshold calibration across real plans.
- New memory entry saved: `feedback_parallel_worktrees.md` — captures
  the "worktree-per-track, merge locally, push only the feature branch"
  preference surfaced in this session.

## 2026-04-29 — main (Gemini CLI Promotion)

- Promoted the repository from a Claude-only marketplace to a **multi-agent plugin collection** supporting both Claude Code and Gemini CLI.
- Added `gemini-extension.json` manifests to `spindev-core`, `spindev-devenv`, and `spindev-deploy` plugin directories.
- Refactored `plugins/spindev-core/hooks/hooks.json` into a **polyglot hook registration** supporting both Claude's `PreToolUse` and Gemini's `BeforeTool` events using `${extensionPath}` for Gemini script resolution.
- Created **TOML command wrappers** for all user-facing slash commands (`/end-session`, `/init-project`, `/pr-prepass`, `/review-plan`, `/create-gh-token`, `/my-status-line`) to enable native Gemini CLI slash command support.
- Established a root-level **`GEMINI.md`** for persistent agent context and installation instructions.
- Updated `CLAUDE.md` and root `README.md` to reflect the dual-agent support and unified project structure.
- Verified that existing `SKILL.md` (skills) and `.md` (subagents) are natively compatible with both agents due to shared standards (YAML frontmatter + Markdown).

Future-you notes:
- The repo is now a valid Gemini CLI extension. Install via `gemini extensions install ./plugins/<plugin>`.
- `hooks/hooks.json` is shared. If you add a new hook, register it in both the `hooks` (Claude) and root (Gemini) sections of the JSON.
- Command wrappers must be maintained in both `.md` and `.toml` formats in the `commands/` directory.
- `SKILL.md` files remain the single source of truth for procedural knowledge.

## 2026-04-29 — main (forgejo + restic-backup skills)

- Designed the source-code backup architecture from a conversation about
  GitHub durability. Chose **Forgejo (self-hosted, Docker) + restic with
  two destinations** (append-only NAS via `rest-server` + write-only
  Cloudflare R2). Rejected GitBucket (minimally maintained), fly.io
  (adds another cloud failure surface), and `git clone --mirror`
  tarballs (no immutability story). User is on Cloudflare already so
  R2 replaced B2.
- Shipped `plugins/spindev-deploy/skills/forgejo/` — Forgejo LTS v15.0.1
  in Docker, `bootstrap.sh` for first-run admin + API token, `add-mirror.sh`
  that uses Forgejo's pull-mirror API and auto-applies branch protection
  (`enable_push: false`, `enable_force_push: false`) so the mirror can't
  be force-pushed even via the API. `create-repo.sh` for on-prem-only
  repos, `verify.sh` health check that warns on stale mirrors.
- Shipped `plugins/spindev-deploy/skills/restic-backup/` — restic 0.18.1
  + rest-server v0.14.0. `init-repos.sh` walks both NAS + R2 setup
  interactively (prints Cloudflare dashboard steps inline). `run-backup.sh`
  is the daily runner: backup → NAS, `restic copy` NAS → R2, ping
  healthchecks.io. systemd timer at 03:17 with 30min jitter.
- **Critical design call:** retention is decoupled. The source box's
  NAS creds are append-only and the R2 token is PutObject-only — neither
  can `forget` *or* `prune`. So `run-backup.sh` only writes; retention
  is `prune-on-nas.sh`, run from the NAS itself with elevated creds and
  an optional `--also-r2` mode that wants a separate Delete-capable R2
  token (kept off the source box). That's the cost of true immutability.
- `restore-drill.sh` restores latest snapshots to scratch and runs
  `git fsck` against any bare repos found — quarterly drill is the
  thing that catches silent backup rot.
- Bumped `spindev-deploy` to `0.3.0`; updated `claude-skills.md`,
  root `README.md`, and both plugin manifests with new keywords
  (forgejo, self-hosted-git, github-mirror, restic, backup, cloudflare-r2,
  append-only). Marketplace blurb refreshed.
- Created remote routine `trig_01QNnLSFPtKkR79KWzjZhFan` — quarterly
  cron `0 14 28 1,4,7,10 *`, first fire 2026-07-28T14:00Z, opens a
  GitHub issue reminding the user to run the drill. Remote agents
  can't reach the NAS/R2, so it's a reminder, not an automated run.

Future-you notes:
- Install was pending at session end ("try to get this setup this week").
  When the user returns to this topic, verify chain status before
  assuming it's running.
- Order of operations for install: Forgejo `bootstrap.sh <hostname>` →
  `add-mirror.sh` per GitHub repo → on the NAS run `install-rest-server.sh`
  → back on source `install-restic.sh` + `init-repos.sh` + `add-source.sh`
  + `install-systemd-units.sh` → `restore-drill.sh` once to confirm.
- Pinned versions in: `forgejo/compose/.env.example`,
  `restic-backup/scripts/install-restic.sh`,
  `restic-backup/scripts/install-rest-server.sh`. Self-heal triggers
  documented in each SKILL.md.
- New memory entry: `project_source_backup_strategy.md` — committed
  architecture, install-pending, drill schedule pointer.

## 2026-04-16 — main (docs: per-skill READMEs + root overview)

- Added plain-English `README.md` to the three skills that lacked one:
  `review-plan/`, `ubuntu-debloat/`, and `hardened-shell/` (short
  landing page that points at the existing `USAGE.md` for the deep
  guide). Every skill now has a human-facing README sibling to its
  `SKILL.md`.
- Created the root `README.md` as the project's human landing page:
  what's in the repo, a **Skills at a glance** table with per-skill
  install targets, Linux/macOS `ln -s` and Windows `mklink /J` install
  commands, pointers to `claude-skills.md` and `SESSION-SUMMARIES.md`,
  and the repo's skill conventions.
- Labeled **installation intent** explicitly per skill (previously only
  `end-session` was called out as user-level, the rest were ambiguous).
  All four are flagged **user-level** — `hardened-shell` is
  additionally a user-level CLI install at `~/.local/bin/hshell`.
  Intent now appears in each skill's README, in `claude-skills.md`, and
  in the root README's summary table.
- Updated `CLAUDE.md` skill conventions: `README.md` per skill is now
  **required**; `USAGE.md` is optional and reserved for skills that
  ship a CLI/runtime users drive directly. Updated the "Adding a new
  skill" checklist to match (README step added, claude-skills.md and
  root README entries made explicit).
- No tests/lint in this repo; quality gates skipped. Doc-only session.

Future-you notes:
- The repo convention is now: `SKILL.md` (Claude-facing, thin) +
  `README.md` (human overview + install intent, required) +
  `USAGE.md` (deep user guide, optional, only for CLI-bearing skills
  like `hardened-shell`). Do not regress to USAGE-only — every new
  skill must ship a README.
- When adding a skill, remember to touch **three** index surfaces:
  its own README, `claude-skills.md`, and the root README's *Skills
  at a glance* table. The `CLAUDE.md` checklist enumerates them.
- No new memory entries — the README/USAGE convention lives in
  `CLAUDE.md` where it belongs (durable project rule, not personal
  context).

## 2026-04-16 — main (session 3)

- Ported the sprites.dev runbook from
  `RadioCalls-Dashboard/.claude/skills/sprites-dev.md` (flat file)
  into this repo as a proper skill at
  `.claude/skills/sprites-dev/{SKILL.md, README.md}`. Content preserved
  verbatim; frontmatter description tightened for trigger reliability.
  Deleted the old flat runbook and junctioned
  `RadioCalls-Dashboard/.claude/skills/sprites-dev` back to the new
  canonical location so that project keeps using it.
- Added explicit slash-command wrappers at
  `.claude/commands/{review-plan.md, end-session.md}` and junctioned
  the whole `.claude/commands/` directory to `~/.claude/commands/` so
  every file under it is a user-level slash command in every project.
  Rationale: `/<name>` typed in a fresh session doesn't always resolve
  via the skill-name auto-match until the skill has been explicitly
  referenced — explicit command files bypass that.
- Updated `claude-skills.md` (new `sprites-dev` entry), root `README.md`
  (new `.claude/commands/` row in "What's in here", new `sprites-dev`
  row in "Skills at a glance", install-intent language generalized),
  and `CLAUDE.md` (preamble now names commands explicitly + a new
  "Slash commands" section documenting the wrapper pattern and the
  directory-junction install).
- Added a `feedback` memory capturing the rule "always ship an explicit
  `.claude/commands/<name>.md` wrapper for any user-invocable slash
  command — don't rely on skill-name auto-matching." The user's own
  observation from this session.
- Swept in a pre-existing uncommitted improvement to
  `end-session/SKILL.md`: added `svelte-check` to the typecheck
  examples and inserted a "Discovery" note in step 11 about checking
  CI workflow files for quality gates not documented in `CLAUDE.md`.
- No tests/lint in this repo; quality gates skipped.

Future-you notes:
- Install pattern for user-level slash commands is now **whole-directory
  junction**: `mklink /J 'C:\Users\<you>\.claude\commands'
  'C:\Users\<you>\src\dev-setup\.claude\commands'`. Any new file under
  `.claude/commands/` here becomes user-level automatically. If a
  command should be project-only instead, put it in that project's
  own `.claude/commands/`, not here.
- `sprites-dev` is deliberately project-level install intent for now
  (tied to how RadioCalls-Dashboard deploys). Promote to user-level
  by symlinking/junctioning into `~/.claude/skills/sprites-dev/` if
  sprites end up being hit from multiple projects.
- `hardened-shell` and `ubuntu-debloat` are still **not** linked into
  `~/.claude/skills/`. User explicitly chose to leave those unlinked
  for now. If you're doing user-wide install later, add them; do not
  silently propose it.

## 2026-04-17 — main (ubuntu-debloat: Brave phase + aarch64 self-heal)

- Added new phase `51-install-brave.sh` so the skill gives arm64 boxes
  a Chromium-based browser. Google hasn't shipped a Chrome arm64 .deb
  yet (announced Q2'26, not on `dl.google.com` as of today); Brave's
  first-party apt repo carries both amd64 and arm64 natively. Chrome
  phase still runs amd64-only; Brave runs on both arches.
- Self-healed four pieces of drift surfaced by the first clean
  `--verify` on this aarch64 box:
  - `80-install-android.sh`: Ubuntu 24.04 renamed
    `android-tools-adb` / `android-tools-fastboot` → `adb` / `fastboot`
    (same-name packages); and gated the qemu-kvm + kvm-group block on
    amd64-only (`qemu-kvm` is an amd64-only transitional meta-package,
    and Android Studio is amd64-only anyway so the emulator toolchain
    doesn't apply on arm64).
  - `40-install-core.sh`: verify path now uses
    `systemctl is-active --quiet ufw` instead of `sudo ufw status` —
    the old check false-failed in `--verify` because sudo can't prompt
    for a password from a non-TTY shell.
  - `lib.sh`: `apt_add_repo` now treats a pre-existing deb822
    `.sources` file as "already configured" alongside `.list`, so
    legacy VS Code (and any other old-install) repos don't read as
    drift. Still creates `.list` on fresh installs.
- Updated `SKILL.md`, skill `README.md`, and `claude-skills.md` to
  describe the new browser coverage (Chrome amd64 + Brave amd64+arm64).
- Committed as `3b07701` and pushed to `origin/main`. GitHub push
  needed a PAT — there's a `GH_TOKEN` in a gitignored `.env` at the
  repo root; sourcing it + `gh auth login --with-token` +
  `gh auth setup-git` is the working pattern.
- No tests/lint in this repo; `scripts/run-all.sh --verify` is the
  local quality gate and it's clean (`all phases completed cleanly`).

Future-you notes:
- The aarch64 self-heal has been run end-to-end on lnxadmin's box, so
  a fresh `--verify` on arm64 Ubuntu 24.04 should now pass zero-issue.
  If it doesn't, the most likely cause is **new** upstream drift, not
  a regression in this session's fixes.
- The stray `cat` file at repo root is debris from an earlier shell
  mistake (not from this session). Leaving it untouched. Delete at
  will — it's one line of ASCII text, no value.
- Chrome arm64 Linux is the only open "we're waiting on upstream" item
  for this skill. When `dl.google.com/linux/direct/google-chrome-stable_current_arm64.deb`
  returns 200 (currently 404), remove the `require_arch amd64` line
  from `50-install-chrome.sh` and add arm64 to the apt source line.
  Brave will keep working either way; you may want to leave Brave in
  and let users choose.
- The one-off `~/install-firefox.sh` and `~/uninstall-firefox.sh` from
  this session are scratch and not part of the skill. Safe to delete.
  (They existed because Firefox was a stopgap browser while we decided
  on Brave — not the skill's browser story.)


## 2026-04-17 — main (init-project skill)

- Added the `init-project` skill (user-level, junctioned into
  `~/.claude/skills/init-project`) with a `/init-project` slash
  wrapper. Idempotent baseline-setup for any project: ensures git repo
  on `main`, detects bringup vs protected mode with the same heuristic
  as `end-session`, manages the `## Project Mode` breadcrumb,
  scaffolds minimal `CLAUDE.md`/`README.md` when missing, stamps a
  canonical Pull Request Workflow rules block bracketed by
  HTML-comment markers for idempotent re-stamping, auto-junctions
  `end-session` and `review-plan` into `~/.claude/skills/`, and
  reports missing plugin skills (`simplify`, `codex`, `superpowers`,
  `claude-md-management`) with install commands.
- Ships `SKILL.md`, `README.md`, three bash helpers
  (`lib.sh`, `detect-mode.sh`, `install-dep-skill.sh`), plus
  `.claude/commands/init-project.md`. Indexed in `claude-skills.md`
  and root `README.md` "Skills at a glance". 8 files, ~355 LOC.
- Caught one bug mid-build: `detect-mode.sh` was classifying this
  bringup repo as `protected` because the bare remote ref `origin`
  (no slash) from `git for-each-ref refs/remotes` slipped through the
  feature-branch filter. Fixed by splitting the probe into separate
  `refs/heads` and `refs/remotes` passes and filtering
  remote-refs-without-a-slash. Verified: now returns `bringup`.
- Initial session started with full brainstorm→spec flow (spec
  committed at `docs/superpowers/specs/2026-04-17-init-project-design.md`,
  commit e025577). User then said the ceremony was overkill for a
  simple single-skill addition — saved as memory
  `feedback_lightweight_for_simple_tasks.md`. Spec doc left in repo
  as historical artifact; explicit delete was not requested.

Future-you notes:
- Ask at end: should the `docs/superpowers/specs/2026-04-17-init-project-design.md`
  spec doc be removed? User called it overkill but didn't explicitly
  request removal. Remove it next session if it still looks like noise.
- On rebase today: this local was 2 commits ahead and 3 commits
  behind origin (ubuntu-debloat work landed in parallel). Rebase was
  clean — `claude-skills.md` was the only shared-edit file and git
  auto-resolved because the two sessions edited different entries.
- `detect-mode.sh` regex lesson: when filtering `git for-each-ref`
  output, split local vs remote passes. Bare remote names have no
  slash and collide with non-slash patterns like `main`.

## 2026-04-18 — main (create-gh-token skill)

- Added new skill `plugins/spindev-devenv/skills/create-gh-token/` —
  question-driven flow that mints a project-scoped fine-grained GitHub
  PAT and wires it into the project's HTTPS git remote so pushes work
  without a credential prompt. Generalized successor to
  `~/src/tod.smith/bootstrap/github-pat.sh` (which is org-specific and
  prescriptive).
- SKILL.md is a thin decision tree: 4 questions
  (create-repos? org-wide vs select repos? sub-permissions: Issues /
  PRs / Workflows / Actions / Pages? branch-protection plan?), then a
  permission-mapping table that builds the recommended PAT-creation
  checklist from the answers, then runs the script.
- `scripts/create-gh-token.sh` — idempotent: parses `<owner>/<repo>`
  from the configured remote (default `origin`; SSH or HTTPS both
  parsed), silent-prompt for token, validates against `/user` and
  `/repos/<owner>/<repo>`, rewrites the remote to
  `https://x-access-token:<TOKEN>@github.com/...`. Modes: `--verify`,
  `--no-set-remote`, `--remote <name>`, `-h`.
- README.md is intentionally self-contained — a per-permission
  reference table (Contents, Administration, Workflows, Actions,
  Pages, etc.) explaining what each unlocks/blocks, plus inline
  org-ruleset (`gh api /orgs/<org>/rulesets`) and per-repo
  branch-protection guidance. User asked for it to be readable
  standalone.
- Slash command `/create-gh-token` shipped in
  `plugins/spindev-devenv/commands/`. First slash command in the
  devenv plugin (previously only spindev-core had any).
- Catalog updated: root `README.md`, `claude-skills.md`,
  `plugins/spindev-devenv/.claude-plugin/plugin.json` (description +
  keywords: github, pat, git-credentials).
- Validation: `claude plugin validate .` passed; `bash -n` clean;
  `--help` and `--no-set-remote` smoke-tested with empty stdin
  (fail-fast working).

Future-you notes:
- The Administration:RW caveat in the README is the load-bearing
  warning. If GitHub ever ships a narrower "create-only" permission,
  loosen Q1 in SKILL.md and the table in README.md (the self-update
  trigger lists this).
- The fine-grained PAT page URL
  (https://github.com/settings/personal-access-tokens/new) appears in
  both SKILL.md and the script. If GitHub renames it, update both.
- Token prefix check (`github_pat_*`) is in
  `scripts/create-gh-token.sh`. Update if GitHub changes the prefix
  scheme.
- Script does NOT chmod 600 `.git/config` after embedding the token —
  README warns the user this is their call (chmod can break some
  tooling). Revisit if rotation discipline turns out to need it.

## 2026-04-20 — main (my-status-line skill)

- Added new skill `plugins/spindev-devenv/skills/my-status-line/` —
  installs a compact Claude Code status line
  `foldername | gitbranch | sandbox | ctx Nk (P%) | Model`. Idempotent
  install (`scripts/install.sh`) copies `statusline.sh` +
  `statusline.py` to `~/.claude/` (stable path; survives plugin-cache
  version bumps) and wires `statusLine` into `~/.claude/settings.json`.
  `--verify` mode for read-only health check; `scripts/uninstall.sh`
  removes cleanly.
- Shipped as two files intentionally. First attempt used
  `python - <<HEREDOC` inside the bash wrapper and silently ate
  Claude Code's piped statusLine JSON payload (python `-` reads the
  script from stdin, which consumed both the script body and the
  payload). Split into `statusline.sh` (bash wrapper) +
  `statusline.py` (parser). The `.sh` locates `python3`/`python`/`py`
  and execs the `.py`.
- Uses Python (not `jq`) for JSON parsing. `jq` isn't on the user's
  Windows Git Bash `PATH` but Python 3.13 is. Portable across
  Linux/macOS/Windows without extra install.
- Sandbox detection = `$HSHELL == 1` (env var set by the
  `hardened-shell` sandbox). Max context = 1M when model id matches
  `[1m]` (case-insensitive), else 200k. Tokens = last assistant
  turn's `input + cache_read + cache_creation` (output excluded —
  it's next-turn context, not current). Smoke-tested end-to-end
  against a real transcript: `dev-setup | main | ctx 85k (8%) | Opus 4.7`.
- Added slash command `/my-status-line` at
  `plugins/spindev-devenv/commands/my-status-line.md`. Per memory
  `feedback_explicit_slash_commands.md` (always ship explicit
  `.claude/commands/<name>.md`).
- Skipped spec/plan ceremony per memory
  `feedback_lightweight_for_simple_tasks.md` — single-skill
  addition, well-scoped.
- Updated `claude-skills.md` (new entry + devenv skill-list row),
  root `README.md` (plugin catalog), and
  `plugins/spindev-devenv/.claude-plugin/plugin.json` description.
- Quality gates: no tests / lint in this repo. JSON manifests
  validated by parse. Helper smoke-tested against real transcript.

Future-you notes:
- Sandbox detection today only covers `hshell`. If Claude Code Web
  or another sandbox grows a detectable env var, extend the
  `HSHELL == "1"` check in `statusline.py`.
- If a new 1M-context model id uses a suffix other than `[1m]`,
  extend the `max_ctx` regex in `statusline.py`.
- `install.sh` runs `chmod +x` on the sh but not the py. Not a
  problem today (the sh execs `python <path>`) but worth remembering
  if the py is ever intended to be invoked directly.

## 2026-04-29 — main (plugin enhancements: subagent + hooks)

Took a pass at expanding the marketplace beyond skills/commands to
also ship a subagent and several PreToolUse hooks. Plugin layout
gained two new directory conventions: `agents/` and `hooks/`.

- **`pr-prepass` subagent lifted into `spindev-core`** from
  `agent.smith/.claude/agents/pr-prepass.md`. Mirrors the repo's PR
  auto-review CI locally before push (gitleaks + shellcheck +
  script-conventions + a Claude PII/secrets/structural pass over the
  diff). Reads `.github/workflows/pr-review.yml` at runtime so it's
  portable across repos with similar CI. New `/pr-prepass` slash
  command. `/end-session` step 11 now auto-dispatches it when
  `pr-review.yml` exists.
- **`sprite-guard` PreToolUse hook in `spindev-deploy`** — blocks
  `sprite exec --` without `bash -c` wrapping, missing
  `MSYS_NO_PATHCONV=1` on Git Bash, curl-flags-before-path on
  `sprite api`, and `--dir` absolute paths on Git Bash. 11/11
  self-tests pass. Backstops the `sprites-dev` skill's rules at
  execution time.
- **`fly-guard` PreToolUse hook in `spindev-deploy`** — blocks
  destructive `fly apps/volumes/machines destroy` and
  `fly tokens revoke` without `--yes`, `fly secrets set VAULT_*=...`
  (silently stripped at runtime — see flyio gotchas), and malformed
  `fly apps create` names; advises (does not block) `fly deploy`
  without `--remote-only`. 14/14 self-tests pass.
- **`gh-workflow` advisory hook in `spindev-core`** — non-blocking
  stderr advisories on `gh repo create` without `--template`,
  `gh pr merge` without `--squash`, `git push` to protected
  branches, and force-push to protected branches. Documented as a
  trial; gh skill says re-evaluate on or before 2026-05-13. 15/15
  self-tests pass.
- **Catalog updates.** `gh` and `flyio` skills were never listed in
  `claude-skills.md` or the root `README.md` plugin catalog. Fixed.
  Each skill that gained a hook also got a "Backstop hook" section
  in its SKILL.md so the matchers and the rules stay in sync.
- **Manifest churn.** `spindev-core` and `spindev-deploy` bumped
  0.1.0 → 0.2.0; `marketplace.json` descriptions updated; `claude
  plugin validate .` passes; all hook scripts pass `shellcheck -S
  warning`.

Decisions deferred (see project memory `project_compound_engineering_eval.md`):

- The planned `plan-reviewer` subagent is paused on a real-project
  trial of `EveryInc/compound-engineering-plugin`. CE ships
  `ce-doc-review` with `ce-adversarial-document-reviewer`,
  `ce-scope-guardian-reviewer`, and `ce-feasibility-reviewer` —
  covers ~70% of `/review-plan`. The trial decides whether to adopt
  CE wholesale (and trim spindev-core to the CE deltas) or build
  plan-reviewer as originally scoped.

Future-you notes:

- **CLAUDE.md gained two new sections:** "Adding a subagent" and
  "Adding a hook". The "Plugin layout" tree now includes `agents/`
  and `hooks/` subdirs and their rules. Use these as the template
  next time.
- **Hook self-test pattern.** Each new hook script was paired with
  a tiny test harness (table of `cmd → expected exit → expected
  warning`) executed inline in the same Bash call. Keep this
  pattern when adding hooks — easier to regression-test rules than
  to debug a wrongly-blocking advisory.
- **`gh-workflow` review window.** If the trial expires (2026-05-13)
  without follow-up, the noise question wasn't asked. Either delete
  the hook entry from `plugins/spindev-core/hooks/hooks.json` or
  decide rules to upgrade to blocking. The skill file documents this
  explicitly.
- **No `pr-review.yml` in this repo.** The new auto-dispatch in
  `/end-session` is a no-op here. If we ever add a PR-review CI to
  dev-setup itself, `pr-prepass` will pick it up automatically.
