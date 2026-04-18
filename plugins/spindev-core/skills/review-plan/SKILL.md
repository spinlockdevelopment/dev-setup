---
name: review-plan
description: Run a cross-model pre-implementation review on a superpowers plan, apply accepted findings, and inject checkpoint review blocks at logical subsystem breaks so long plans get batched cross-model reviews instead of per-task reviews. Supports parallel-track plans (one worktree per track). Use when the user invokes `/review-plan` or says phrases like "review the plan", "harden the plan", "add checkpoints to the plan", or "cross-model review the plan" after a plan has been generated (typically by superpowers:writing-plans). Skip checkpoint injection for short plans (≤5 tasks) — they do not benefit from batching.
---

# /review-plan

Review and harden a freshly generated implementation plan before execution. Two review passes over the plan, user triages findings, skill applies accepted revisions, then (for long plans) injects checkpoint review blocks. Hand back to the user for normal execution.

Announce at start: "Running /review-plan to review and harden the plan before implementation."

## Triggers

- `/review-plan` (slash command)
- Phrases: "review the plan", "harden this plan", "add checkpoints to the plan", "cross-model review the plan"

## Arguments (optional)

- Path to a specific plan file — if omitted, resolve via session context → filesystem → ask (see step 1)
- `--no-checkpoints` — force skip checkpoint injection even for long plans
- `--checkpoints` — force checkpoint injection even for short plans

## Prerequisites

- A plan file exists at `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` (or user-supplied path)
- `/codex:review` and `/codex:adversarial-review` are available (codex plugin installed)
- `superpowers:requesting-code-review` is available

If anything is missing, stop and tell the user what is not available before doing any review work.

## The flow

### 1. Locate and load the plan

Resolve the plan path in this order — only ask the user as a last resort:

1. **Explicit argument** — if the user passed a path, use it.
2. **Session context** — scan the current conversation for a plan path. `superpowers:writing-plans` typically announces the saved path ("Plan complete and saved to `docs/superpowers/plans/...`"), the user may have referenced one, or a prior skill may have handed one off. If exactly one plan path appears in session, use it.
3. **Filesystem** — look under `docs/superpowers/plans/`. If there is exactly one `.md` or one clearly-recent file, use it.
4. **Ask the user** — only if the above are ambiguous or empty.

Read the plan and confirm it matches the writing-plans format (header, `### Task N:` sections, bite-sized steps). If it does not, ask the user which file they meant rather than guessing.

### 2. Parse plan structure

Count tasks (`### Task N:` headers), list files touched, note obvious coupling between tasks. Record the task count — it drives the checkpoint decision later. Note any repeated work across tasks as a candidate for the simplification pass.

### 3. Commit the plan if not already committed

Cross-model review scopes to git state, so the plan must be a committed object. Check `git status`. If the plan file is untracked or has unstaged changes, stage only that file and commit with a message like `plan: add <feature> implementation plan`. Record the resulting SHA. If the user is in a worktree, this is the normal worktree flow — commit locally, no push.

### 4. Simplification pass (inline)

Review the plan against this checklist. You are looking for structural issues in the plan, not the code it will produce:

| Check | What to flag |
|---|---|
| DRY | Same work described in multiple tasks; shared helper built twice |
| YAGNI | Features, abstractions, or flags not required by the stated goal |
| Scope creep | Tasks implementing things outside the spec |
| Over-engineering | Premature abstraction, config systems, plugin frameworks for single-use code |
| Missing tests | Task with implementation code but no corresponding test step |
| Placeholder drift | "TBD", "add validation", "handle edge cases" without concrete content |
| Type/name drift | `foo()` in Task 3 but `fooBar()` in Task 7 |
| Granularity | Steps bigger than 2-5 minutes or combining multiple actions |

Produce a numbered list of concrete revision suggestions. Do NOT apply any yet.

### 5. Adversarial cross-model pass (codex)

Run the adversarial review as a challenge pass on the plan design, not a code review:

Invoke `/codex:adversarial-review --wait --base <plan-commit>^ --scope branch plan review: challenge the approach, assumptions, task decomposition, and tradeoffs in the plan file` (substitute the actual plan commit SHA from step 3).

Use `--wait` (foreground) because the output is needed before proceeding. Capture codex's output verbatim — do not paraphrase or filter at this stage. Codex will challenge the approach, surface hidden assumptions, and flag design risks. That is the whole point of the cross-model angle.

### 6. Synthesize and present findings

Show the user:

1. Numbered simplification findings from step 4
2. Numbered adversarial findings from step 5 (codex output, verbatim or lightly structured)

Ask: "Which findings should I apply? Options: `all`, `none`, `selected <numbers>`, or give free-text guidance."

Wait for the answer. Do not edit the plan until the user has triaged.

### 7. Apply accepted revisions

Edit the plan file directly to incorporate accepted findings. Keep edits minimal — fix what was flagged, do not rewrite. Preserve the writing-plans format (header, Task structure, bite-sized steps, code blocks with real content).

### 8. Checkpoint decision

Decide whether to inject checkpoints based on task count and explicit flags:

| Condition | Action |
|---|---|
| `--no-checkpoints` passed | Skip. Note reason in report. |
| `--checkpoints` passed | Inject at every logical break regardless of length. |
| Tasks ≤ 5 | Skip. A short plan does not benefit from batching. |
| Tasks 6+ | Insert at logical breaks (see below) — never on fixed intervals. |

**Finding logical breaks:**

A logical break is where the preceding tasks form a complete, testable, reviewable unit. Look at task titles and files touched. Good signals:

- **Subsystem boundaries** — tasks cluster around a domain (API, DB, migration, auth, backend, frontend, docs, tests). When the next task moves to a different subsystem, that is a break.
- **Dependency boundaries** — if Tasks N+1 cannot start until 1-N are green, the checkpoint goes after Task N.
- **Layer transitions** — data model → API → UI → docs. Each transition is a natural break.
- **Test scope changes** — unit → integration → E2E. The preceding batch has likely completed a testable unit.

Do not invent breaks where tasks are tightly interlocking. If every task depends on the previous one with no clean seam, there is no natural break — default to one review at the end and say so in the report.

### 9. Parallel-track detection

Before injecting checkpoints, check whether the plan contains **independent tracks** — groups of tasks that can progress in parallel without blocking each other. Signals:

- Explicit `## Track: <name>` headings in the plan
- Task titles clustering into non-overlapping domains (backend vs frontend vs docs) with no cross-references
- A "Parallelism" or "Dependencies" note in the plan's architecture section

If parallel tracks are present, offer the user a parallel execution path:

> "This plan has independent tracks: [list]. Execute them in parallel using one worktree per track, with checkpoint reviews per track — or keep it sequential on one branch. Which? (parallel / sequential)"

**If parallel:**
- Reorganize (if needed) so the plan groups tasks under `## Track: <name>` headings, each track independently numbered (Track A: Tasks 1-4, Track B: Tasks 1-7, etc.)
- Insert checkpoints within each track at that track's logical breaks
- Inject the note from `assets/parallel-tracks-note.md` near the top of the plan (after the Architecture block, next to the standard header note). It explains the worktree-per-track execution model so any executor honors it.
- Add an integration checkpoint at the end, after all tracks merge back — that is where cross-track interactions get reviewed

**If sequential:** proceed with single-track checkpoints at the logical breaks from step 8. Warn the user once that serial execution on one branch means review scope spans whatever commits exist between SHAs — if they later want to parallelize, switch to worktrees.

### 10. Inject checkpoint blocks

For each checkpoint (whether single-track or per-track), insert the block from `assets/checkpoint-template.md` between the relevant tasks. Substitute placeholders:

- `<LETTER>` — A, B, C, ... for each checkpoint in order within its track
- `<N>-<M>` — the task range this checkpoint covers
- `<M+1>` — the next task number

For parallel tracks, prefix checkpoint letters with the track (e.g., `Checkpoint A.1` for Track A's first checkpoint, `Checkpoint B.1` for Track B's). The `CHECKPOINT_BASE` and `CHECKPOINT_HEAD` in each block refer to that track's branch, not the plan branch.

Also inject the note from `assets/plan-header-note.md` right after the plan's Architecture/Tech Stack block. This note tells any downstream executor to honor the checkpoint blocks and how to interact with per-task review behavior.

### 11. Commit the revised plan

Stage only the plan file and commit: `plan: apply review findings + checkpoint markers`. This gives a clean diff that shows exactly what the review pass changed.

### 12. Report and hand off

Give the user a short report:

- Simplification findings applied (which numbers, briefly what each did)
- Adversarial findings applied (which numbers, briefly what each did)
- Findings skipped and why
- Number of checkpoints inserted and where — or why none were (task count, `--no-checkpoints`)
- Next step: "Plan is ready. Say 'continue with implementation' to proceed. Recommended executor: `executing-plans` (inline + checkpoint-friendly). `subagent-driven-development` also works but its per-task code-quality review overlaps with the checkpoint review — see the injected header note."

Then stop and wait.

## Why this flow

- **Review the design before the code.** Plan-phase problems are cheap to fix; code-phase problems are not.
- **Cross-model review on plans.** Codex (different model) challenges assumptions Claude made while authoring the plan. Self-review misses things cross-model review catches.
- **Checkpoints only when they pay off.** Short plans don't benefit from batched reviews — the overhead outweighs the signal. The 5-task threshold is a heuristic — override with `--checkpoints` if a short plan is high-risk.
- **Logical breaks, not arithmetic.** Checkpoints land at subsystem/layer/dependency boundaries where the preceding tasks form a testable unit. Fixed intervals cut across natural seams and produce noisy reviews.
- **Parallel tracks via worktrees.** Running tracks in parallel on one branch interleaves commits and muddies review scope. One worktree per track keeps each track's branch linear, so `/codex:review --scope branch` sees only that track's work.
- **Checkpoints encoded in the plan itself.** Any executor can honor them. The plan is self-describing. No second skill needed at execution time.
- **Codex at checkpoints, not per task.** Cross-model review per task is expensive and noisy for small changes. Batching gives codex a meaningful, testable unit to critique.

## Interaction with other skills

- **superpowers:writing-plans** — runs first; produces the plan this skill reviews.
- **superpowers:requesting-code-review** — invoked by the injected checkpoint blocks. Still the primary same-model code reviewer.
- **/codex:review** and **/codex:adversarial-review** — this skill invokes both; they remain the cross-model review tools.
- **superpowers:executing-plans** — recommended executor after `/review-plan`. Its batched-checkpoint model matches the injected blocks naturally.
- **superpowers:subagent-driven-development** — also works, but its per-task two-stage review overlaps with checkpoint review. The injected header note tells it to keep spec-compliance per task and run the checkpoint block instead of per-task code-quality review.

Do not invoke this skill twice on the same plan in one session. It is idempotent in principle (the checkpoint note prevents double injection), but a second pass adds noise.

## Self-improvement

If during execution you notice a clear bug in this skill — wrong command flag, broken logic, a reference to something that no longer exists — fix it in place in `.claude/skills/review-plan/SKILL.md` and mention the fix in the final report. Judgment-call improvements (better phrasing, new steps): propose and ask before editing.
