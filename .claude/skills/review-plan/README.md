# review-plan

A Claude Code skill that hardens a freshly generated implementation plan
before you start executing it.

## Purpose

Plans produced by `superpowers:writing-plans` get one author and one pass.
Plan-phase mistakes (over-engineering, duplicated work, missing tests,
drifting names, scope creep) are much cheaper to fix in the plan than in
the code. This skill forces a second look — plus a **cross-model** look —
before any code gets written.

## Why it exists

- Same-model self-review misses things a different model would catch.
- Long plans benefit from **batched** reviews at subsystem seams, not
  per-task reviews that drown you in noise for trivial tasks.
- Running parallel tracks on one branch interleaves commits and turns
  `/codex:review --scope branch` into garbage. One worktree per track
  fixes that — but only if the plan says so up front.
- The right place to encode "review at this point" is the plan file
  itself, so any executor (inline or subagent-driven) honors it.

## What it does

1. Locates the plan file (session context → filesystem → asks).
2. Commits the plan if untracked, so cross-model review can scope to git.
3. **Simplification pass** — inline review against a DRY/YAGNI/scope
   checklist, produces numbered findings.
4. **Adversarial cross-model pass** — runs `/codex:adversarial-review` to
   challenge assumptions, approach, and tradeoffs.
5. Presents both sets of findings — user triages with `all` / `none` /
   `selected <numbers>` / free text.
6. Applies accepted revisions directly to the plan.
7. **Checkpoint decision**:
   - Short plans (≤5 tasks) → skip checkpoint injection.
   - Long plans (6+ tasks) → inject `### Checkpoint` blocks at logical
     subsystem / layer / dependency breaks.
8. **Parallel-track detection** — if the plan has independent tracks
   (backend vs frontend, etc.), offer worktree-per-track execution with
   per-track checkpoints plus an integration checkpoint at merge-back.
9. Commits the revised plan so the diff shows exactly what review
   changed.
10. Reports and hands back for normal execution (`executing-plans`
    recommended).

## How to trigger it

- Slash command: `/review-plan`
- Phrases: "review the plan", "harden this plan", "add checkpoints to
  the plan", "cross-model review the plan"
- Optional flags: `--no-checkpoints` (force skip), `--checkpoints` (force
  inject even on short plans)

## Prerequisites

- A plan file at `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` (or
  user-supplied path) in the writing-plans format.
- The `codex` plugin installed (`/codex:review`,
  `/codex:adversarial-review`).
- `superpowers:requesting-code-review` available.

If any of these are missing, the skill stops and says so rather than
pretending to review.

## Installation intent

**User-level.** This skill is generic to any project that uses
superpowers plans — install it at `~/.claude/skills/review-plan/` so
it's available everywhere, not just inside `dev-setup`.

Symlink from this repo so updates propagate:

```bash
# Linux / macOS
ln -s ~/src/dev-setup/.claude/skills/review-plan ~/.claude/skills/review-plan
```

```bash
# Windows (Git Bash, no admin needed — creates a junction)
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 cmd.exe /c mklink /J \
  'C:\Users\<you>\.claude\skills\review-plan' \
  'C:\Users\<you>\src\dev-setup\.claude\skills\review-plan'
```

See `claude-skills.md` in the repo root for the general install pattern
and the Windows junction trick.

## Relationship to other skills

- **superpowers:writing-plans** — runs first, produces the plan this
  skill reviews.
- **superpowers:executing-plans** — recommended executor after this
  skill runs. Its batched-checkpoint model matches the injected blocks
  naturally.
- **superpowers:subagent-driven-development** — also works, but its
  per-task review overlaps with the checkpoint blocks. The injected
  header note tells it to keep spec-compliance per task and defer
  code-quality review to the checkpoint.
- **/codex:review** and **/codex:adversarial-review** — invoked during
  the pass.

Do not run this skill twice on the same plan — it's idempotent in
principle but a second pass just adds noise.

## Files

| File | Purpose |
|---|---|
| `SKILL.md` | Claude-facing decision tree (what this skill executes) |
| `README.md` | This file — human-facing overview |
| `assets/checkpoint-template.md` | Boilerplate injected at each checkpoint |
| `assets/plan-header-note.md` | Header note telling executors to honor checkpoints |
| `assets/parallel-tracks-note.md` | Note added when the plan has independent tracks |
