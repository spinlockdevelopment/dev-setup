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

## 2026-04-16 — main (tune global Claude config)

- No changes to this repo. Session was run from here but edited global
  Claude config only: `~/.claude/hooks/cd-strip-permission.js` and
  `~/.claude/settings.json`.
- Extended `cd-strip-permission.js` with two new branches.
  (a) Force-allow `git commit -m "$(cat <<'EOF' ... EOF)"` — the glob
  `Bash(git commit -m *)` misses multi-line heredoc bodies
  intermittently (~1/30 per a 10-day, 80-session transcript scan).
  (b) Parse `sprite exec -- [bash -c '<body>' | <cmd>]`, strip an
  inner `cd <path> &&` prefix, then re-evaluate the inner command
  against the user's allow/ask/deny rules — so destructive inner
  commands (`rm -rf`, etc.) surface as `ask` even inside the sandbox.
- Added six allow patterns to `~/.claude/settings.json`: `mkdir *`,
  `bash -n *`, `chmod +x *`, `curl -sI http://localhost:*`, and
  `sprite api *`. The `sprite exec *` blanket allow was *not* added,
  so the new hook is fail-closed: a hook error prompts instead of
  silently allowing.
- No tests / lint in this repo; quality gates skipped.

Future-you notes:
- If you touch `cd-strip-permission.js`, pipe-test every branch
  before shipping. There are now four: heredoc git commit, sprite
  exec, cd-prefix, passthrough. Payload shape is
  `{"tool_name":"Bash","tool_input":{"command":"..."}}`.
- `Bash(sprite exec *)` is deliberately absent from the allow list.
  Do not add it back without also removing the sprite-exec handler
  in the hook — otherwise you re-introduce fail-open semantics.
- New memory entry: `feedback_fail_closed_permission_hooks.md`.

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

