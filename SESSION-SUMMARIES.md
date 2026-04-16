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
