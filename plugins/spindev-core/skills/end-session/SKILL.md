---
name: end-session
description: Wraps up a working session cleanly so a following /clear loses nothing important — syncs docs, prunes and updates memory, reconciles TODOs, runs local quality gates, writes a session summary, and (when appropriate) creates a PR with auto-merge + squash. Use this skill whenever the user invokes /end-session or says phrases like "get ready to clear context", "wrap up this session", "prep for /clear", "we're done for now", "let's wrap up", or otherwise signals the session is ending. This skill is itself the explicit permission to create a PR and enable auto-merge when session context clearly indicates feature work is complete.
---

# /end-session

Wraps up a working session so a following `/clear` loses nothing important. Think of it as the checklist you would want to run every time you are done for the day or about to reset context mid-thread.

Announce at the start: "Running /end-session to wrap up this session."

## Triggers

- `/end-session` (slash command)
- Phrases: "get ready to clear context", "wrap up this session", "prep for /clear", "we're done for now", "let's wrap up", and similar

Optional arguments the user may include at invocation:
- A clear signal that feature work is done ("done", "ready to merge", "ship it") — grants PR + auto-merge authority without re-asking
- `merge` / `no-merge` — force or skip the PR step
- `wait` / `no-wait` — override CI wait behavior

## What this skill authorizes

Invoking `/end-session` grants permission to:
- Update `CLAUDE.md`, memory files, project docs, TODO files, and `SESSION-SUMMARIES.md` in this turn
- Create a PR and enable auto-merge + squash *when the session context clearly indicates feature work is complete*

It does **not** authorize:
- Destructive git operations (force-push, `reset --hard`, `branch -D`, `stash drop`, `clean -fd`) — always ask
- Direct pushes to `main`, `staging`, or `prod` in protected mode
- Running `/clear` itself — that is the user's next action

## Project mode: bringup vs protected

The wrap-up steps depend on the project's phase. Detect at the start.

| Mode | Signals | PR behavior |
|---|---|---|
| **Bringup** | `main` is the only branch, commits go straight to `main`, no PR history, often no remote yet | Commit + push to `main`, no PR |
| **Protected** | Feature branches exist, history shows squash merges / PRs, `main` has protection rules or a clear convention | PR from feature branch, squash + auto-merge |

Record the detected mode as a breadcrumb under a `## Project Mode` heading in `CLAUDE.md`. If a bringup breadcrumb exists but the repo now shows feature branches or PR history, remove the breadcrumb and treat as protected from now on. The breadcrumb prevents re-detection on every session.

There should always be a `CLAUDE.md`. If one does not exist, create it before writing the breadcrumb. Ask the user for anything you genuinely cannot infer (project purpose, stack, notable conventions). A minimal `CLAUDE.md` with scope + mode is a fine starting point.

## The flow

Walk through these steps in order. Announce the current step as you go. Skip steps that clearly do not apply and say so. For a large session, consider using a task list so interruptions are recoverable.

### 1. Read the state

- `git status`, current branch, remote
- `git log <upstream>..HEAD` to see un-pushed work
- `git worktree list` — detect whether we are in a worktree vs the main checkout, and note the path of the root (main) worktree
- Active plan files under `docs/superpowers/plans/` or equivalent
- Current TodoWrite state
- Whether `CLAUDE.md`, `SESSION-SUMMARIES.md`, and any memory system (e.g., `MEMORY.md`) exist

If there is no git repository at all and the project looks code-shaped, offer to `git init`. If the user declines, continue with the docs/memory/TODO steps anyway — a `CLAUDE.md` still helps.

### 2. Project mode check

Detect bringup vs protected. Write or remove the breadcrumb in `CLAUDE.md` as needed.

### 3. CLAUDE.md hygiene

Create it if missing. If present, check it still reflects the repo — new top-level directories, changed stack, new sub-`CLAUDE.md` references the root should point at.

### 4. Uncommitted and untracked review

List staged, unstaged, and untracked changes. Ask the user what to do with each group:
- Commit as part of wrap-up
- Stash
- Leave for next session
- Discard (destructive — require typed confirmation like `discard`)

### 5. Secret and scratch sweep

Before any commit or push, scan staged content for anything that looks like credentials (`.env`, tokens, API keys, private keys, cookie jars, session files). Flag scratch/debug files (`.scratch`, `tmp_*`, `debug_*`, notebook checkpoints) that should not land in a commit. Do not auto-remove — surface and ask.

### 6. .gitignore update

For untracked files that clearly belong in `.gitignore` (build artifacts, caches, `node_modules`, `__pycache__`, IDE files, OS junk), propose additions. Ask on ambiguous cases. Update `.gitignore` before the PR so the diff stays clean. This is one of the most common sources of noise in PRs and it is cheap to prevent.

### 7. Docs sync pass

Update:
- Root `CLAUDE.md` and every `CLAUDE.md` it references
- Index / manifest files (e.g., a file index in `CLAUDE.md`, module READMEs that enumerate files)
- Plan files under `docs/superpowers/plans/` — mark completed steps, close finished plans
- Other project docs affected by the session's changes

If a new doc would genuinely help (a new subsystem with no README, a migration guide, an API note), propose it with a suggested path and purpose. Create only after the user confirms.

### 8. TODO hygiene

- Mark finished items complete in TodoWrite
- Prune completed entries from project TODO files (e.g., `docs/CLAUDE-TODO.md`)
- Capture TODOs raised in conversation but never written down
- When adding a new TODO, note its origin — the decision or discussion it came from — so future-you can reconstruct the why

### 9. Memory pass

If the environment has a persistent memory system (e.g., `MEMORY.md` with linked memory files), read it and for each entry:
- Obviously stale (references deleted files, superseded decisions, commands that no longer exist) — purge it, announce what was purged and why
- Questionable but possibly still relevant — ask
- Add new insights from this session that would help future sessions

When a learning is more of a durable project rule than personal context, write it in `CLAUDE.md` instead of (or in addition to) memory.

### 10. Session summary

Append an entry to `SESSION-SUMMARIES.md` at the repo root. Create the file if missing and add a one-line reference to it from `CLAUDE.md` (e.g., "Session history: see [SESSION-SUMMARIES.md](SESSION-SUMMARIES.md)").

Entry format — aim for balance, not a wall of text:

```
## YYYY-MM-DD — <branch-name>
- 3-5 bullets of what shipped or moved forward
- Follow-ups, blockers, or partially-complete work
- New TODOs spawned (note origin — which decision or discussion)
- Anything future-you should know before touching this area again
```

Keep it scannable. A future session should be able to read one entry and pick up work without re-reading the whole conversation.

### 11. Pre-PR quality gates

Run locally, even if CI also runs them:
- Test suite (project's command — `pytest`, `npm test`, `cargo test`, etc.)
- Type check if the project has one (`tsc --noEmit`, `mypy`, `svelte-check`, etc.)
- Lint — **run even if lint is not in the CI gate**; the round-trip cost of a failing CI lint is worse than a few seconds locally

**Discovery:** Do not rely solely on `CLAUDE.md` for the list of commands. Also check the CI workflow files (`.github/workflows/*.yml`, `.gitlab-ci.yml`, `Makefile`, `package.json` scripts) for quality gates that may not be documented. If you find a gate in CI that is not in `CLAUDE.md`, run it *and* add it to the Testing section of `CLAUDE.md` so future sessions do not repeat this gap.

If any gate fails, stop and report. Do not proceed to review offers or PR.

### 12. Review skill offers (threshold-gated)

If the session's changes are substantial — roughly **hundreds of lines changed**, **10+ files touched**, or context clearly indicates a **major feature or refactor** — offer to run any of:
- `/codex:review`
- `/codex:adversarial-review`
- `/simplify`

For small bugfixes or trivial changes, skip the offer — it is noise. Use judgment; when in doubt, offer.

### 13. Sync with origin (critical before PR)

Squash merges on `main` leave local commits orphaned: same content, different SHA, so `git log` looks like you still need to push work that is already merged. This has repeatedly caused confusion. Always reconcile before creating the PR:

- `git fetch origin`
- If the feature branch is behind: rebase (clean feature branch) or merge (if others are on this branch)
- Verify `git log origin/main..HEAD` shows only genuinely new commits
- If you see commits that look suspiciously like things already in `main`, inspect the content, not just the SHA — squash merges change SHAs but preserve file content

Do not skip this step. A PR opened without syncing will mislead both us and reviewers.

### 14. Push and PR decision

**Bringup mode:** commit to `main`, push, stop at the pre-clear report.

**Protected mode, work complete** — context clearly indicates the feature is done, or the user said so at invocation:
- Push feature branch
- Create PR with title + body pulled from the session summary and recent commits (keep it tight — what changed, why, test plan)
- Enable auto-merge + squash

**Protected mode, work not complete** — multi-session feature in progress:
- Push feature branch
- Skip PR
- Note in the pre-clear report that the PR is deferred to a future session; this is normal

When uncertain whether work is complete, ask. Do not create a PR on a guess.

### 15. CI wait behavior

After enabling auto-merge:
- Test runtime known and short (**< 30s**): wait for CI, confirm green, then report done
- Tests known to be long-running (minutes): fire and forget — auto-merge will land on green
- Unknown runtime: ask the user which they prefer

### 16. Worktree cleanup (if applicable)

If the session was run inside a git worktree, the desired end state depends on whether the work is done.

**Work complete and PR merged (or about to auto-merge):**
- Ask before removing the worktree — this is a destructive op
- Switch back to the root (main) checkout: `cd <root-worktree-path>`
- Update the local main: `git checkout main && git pull`
- Remove the worktree: `git worktree remove <worktree-path>` (use `--force` only after asking, e.g., if the worktree has untracked files you've already reviewed)
- Delete the merged feature branch locally if it still exists
- Confirm the user is now in the main checkout on `main`

**Work complete, fire-and-forget auto-merge (long CI):**
- Do not remove the worktree now — CI has not confirmed green yet
- Note in the pre-clear report that worktree cleanup should happen in a future session once the PR lands

**Work not complete (multi-session feature):**
- Leave the worktree in place
- Stay in the current directory
- Note the worktree path in the pre-clear report so it is easy to resume

Project-specific worktree setup (e.g., symlinks, data directories) does not need special handling here — `git worktree remove` handles the git side, and any project-specific cleanup is the project's responsibility.

### 17. Pre-clear report

Final message back to the user before they run `/clear`. A short checklist:
- What was updated (docs, memory, TODOs, session summary, .gitignore)
- PR status (created + auto-merge on? pushed only? skipped?)
- Worktree state (removed and now in root on `main`? preserved at `<path>` for continued work? cleanup deferred until CI lands?)
- Anything pending (CI, review, user action needed before clear)
- Explicit verdict: "safe to /clear" or "do X first"

If you made any self-updates to this skill during the session, mention them here.

## Destructive operations — always ask

Always pause and confirm before:
- `git reset --hard`, `git clean -fd`, `git branch -D`, `git push --force`
- `git stash drop`, `git rm` on untracked or uncommitted files
- Removing or overwriting files the user has not confirmed
- Deleting memory entries the user has not signed off on

One authorization does not carry across operations — re-ask each time.

## Self-improvement

If during execution you notice:
- A **clear bug** in this skill (wrong command, broken logic, outdated file path, reference to something that no longer exists): fix it and note the fix in the pre-clear report.
- A **judgment-call improvement** (better phrasing, a new step worth adding, reordering): describe the proposed change and ask before editing.

**This skill is served from a read-only plugin cache** (`~/.claude/plugins/cache/spindev-core@spinlockdevelopment/<version>/`). Edits there do not persist and do not propagate. To actually apply the fix, edit the authoritative copy at `plugins/spindev-core/skills/end-session/SKILL.md` in a clone of `spinlockdevelopment/dev-setup`, commit (bringup: straight to `main`; protected: feature branch + PR), and push. Consumers pick it up on their next `/plugin marketplace update`. The idea is that this skill gets sharper every time it runs.

## Not a replacement for

`superpowers:finishing-a-development-branch` covers a simpler 4-option flow (merge locally / push+PR / keep as-is / discard) with no docs or memory work. This skill is the superset for end-of-session wrap-up. Do not invoke both in the same run — they will fight over the PR decision.

## Why these defaults

- **PR + auto-merge + squash** matches the preferred workflow for protected-branch projects where `main` accumulates squash commits from feature branches.
- **Lint even without CI** catches issues that otherwise cost another round-trip.
- **Always sync with origin** — orphaned-commit confusion from squash merges is a recurring pain and the cleanup is cheap.
- **Session summary as an appended file** gives durable cross-session context, which memory alone cannot reliably provide.
- **Threshold-gated review offers** — reviews on tiny changes are noise; reviews on large changes save real time.
- **Ask before destructive ops, always** — the cost of a wrong destructive action dwarfs the cost of a confirmation prompt.
