# end-session

A user-level Claude Code skill that cleanly wraps up a working session so a following `/clear` loses nothing important.

## Purpose

Ending a session well is tedious but important. Docs go stale, memory drifts, TODOs pile up, PRs get opened on un-synced branches, and the next session pays the price. This skill makes the wrap-up a single command instead of a 16-step manual checklist that is easy to half-do.

## Why it exists

- The manual wrap-up process was being run by hand every session — it was consistent enough to automate.
- Context between sessions is fragile. Without a durable handoff, future-you re-reads the whole conversation or misses things entirely.
- PRs were going out on branches that were behind `origin/main` after squash merges, producing confusing diffs.
- Memory entries and project docs drift out of sync with the code if nobody is tending them at session boundaries.

## What it does

Sorted by phase of the wrap-up:

### Detection
- Detects whether the project is in **bringup mode** (single `main` branch, raw commits) or **protected mode** (feature branches + PRs)
- Records the detected mode as a breadcrumb inside `CLAUDE.md` so it does not re-detect every session
- Removes the breadcrumb automatically when a project graduates from bringup to protected

### Cleanup
- Ensures a `CLAUDE.md` exists at the repo root; creates one with your input if missing
- Lists staged, unstaged, and untracked changes and asks what to do with each group
- Scans staged content for secrets and scratch/debug files before anything is pushed
- Updates `.gitignore` for untracked files that clearly belong there (asks on ambiguous cases)

### Documentation
- Updates the root `CLAUDE.md` and every `CLAUDE.md` it references
- Updates index and manifest files that enumerate modules or files
- Marks completed steps in active plan files (`docs/superpowers/plans/*`)
- Proposes new docs when a subsystem is missing one and creates them after you confirm

### Bookkeeping
- Marks finished items complete in the current TodoWrite list
- Prunes completed entries from project TODO files
- Captures TODOs raised in conversation but never written down, noting where each originated
- Reviews the persistent memory system (e.g., `MEMORY.md`), purges obviously stale entries, asks about questionable ones, and adds new insights from the session
- Routes durable project rules into `CLAUDE.md` rather than personal memory when appropriate

### Session summary
- Appends a dated entry to `SESSION-SUMMARIES.md` at the repo root
- Creates the file on first use and adds a reference line to it from `CLAUDE.md`
- Each entry is 3-5 bullets of what shipped, follow-ups, new TODOs with their origin, and anything future-you should know

### Quality gates
- Runs the test suite locally
- Runs the type checker if the project has one
- Runs the linter even when it is not in the CI pipeline
- Stops and reports if any gate fails — does not proceed to review or PR

### Review offers (threshold-gated)
- For substantial sessions (roughly hundreds of lines changed, 10+ files touched, or a major feature), offers to run:
  - `/codex:review`
  - `/codex:adversarial-review`
  - `/simplify`
- Skips the offer for trivial bugfixes to avoid noise

### Origin sync (critical)
- Fetches `origin` and reconciles the feature branch before any PR
- Catches the common trap of squash-merged commits that still look un-pushed locally because the SHAs changed
- Rebases or merges depending on whether other collaborators are on the branch

### Push and PR
- **Bringup mode:** commits and pushes to `main`, no PR
- **Protected mode, work complete:** pushes feature branch, creates PR, enables auto-merge + squash
- **Protected mode, work not complete:** pushes feature branch only, skips PR, notes the deferral (multi-session work is normal)

### CI wait
- Waits for CI and confirms green when tests run in under 30 seconds
- Fires and forgets when tests are known to be long-running
- Asks when runtime is unknown

### Worktree handling
- Detects whether the session is running inside a git worktree vs the main checkout
- After a successful PR (or enabled auto-merge with short CI): asks before removing the worktree, then returns you to the root checkout on `main` with the feature branch cleaned up
- If work is not finished: leaves the worktree in place and stays where you are — multi-session features are normal
- If auto-merge was fired-and-forgotten against long CI: defers worktree cleanup to a future session so nothing is removed before CI confirms green

### Final report
- Lists what was updated (docs, memory, TODOs, session summary, `.gitignore`)
- Reports PR status (created + auto-merge, pushed only, or skipped)
- Reports worktree state (removed and returned to root, preserved for continued work, or deferred)
- Flags anything pending before `/clear` is safe

## What it will not do without asking

- Any destructive git operation — force-push, `reset --hard`, `branch -D`, `stash drop`, `clean -fd`, `rm` on unconfirmed files
- Delete memory entries flagged as questionable
- Push directly to `main`, `staging`, or `prod` in protected mode
- Run `/clear` itself — that stays as your next action

## How to trigger it

- Type `/end-session`
- Or say something like: "get ready to clear context", "wrap up this session", "prep for /clear", "we're done for now", "let's wrap up"
- Optional arguments at invocation:
  - "done" / "ready to merge" / "ship it" — grants PR + auto-merge without re-asking
  - `merge` / `no-merge` — force or skip the PR step
  - `wait` / `no-wait` — override CI wait behavior

## Self-improvement

The skill is allowed to update itself during a run:

- Clear bugs (wrong command, outdated path, broken logic) get fixed in place and noted in the final report
- Judgment-call improvements (better phrasing, reordering, new steps) are described and confirmed before being applied

The intent is that the skill gets sharper each time it runs instead of bit-rotting.

## Relationship to other skills

- **Do not** invoke `superpowers:finishing-a-development-branch` in the same run — it also wants to drive the PR decision and the two will fight. This skill covers a superset of its behavior.
- **Pairs with** `/codex:review`, `/codex:adversarial-review`, and `/simplify` — offered when session size crosses the threshold.
- **Supersedes** the manual pre-`/clear` wrap-up ritual.

## Installation

Installed at `~/.claude/skills/end-session/` — user-level, so it applies to every project.

Files:
- `SKILL.md` — the skill definition Claude loads
- `README.md` — this file
