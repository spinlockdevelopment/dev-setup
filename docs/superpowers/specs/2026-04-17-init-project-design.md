# init-project — design spec

Date: 2026-04-17
Status: approved for planning

## Purpose

A repeat-safe, user-level skill that brings any project up to a baseline
state for working with Claude. It ensures the project is a git repo on
`main`, records the correct project-mode breadcrumb (bringup vs
protected), scaffolds a minimal `CLAUDE.md` and `README.md` if missing,
stamps a canonical PR-workflow rules block into `CLAUDE.md`, and
verifies the dependency skills this workflow relies on are accessible.

The skill is idempotent: every action checks current state first and
no-ops when the project already matches the desired baseline. It can be
run multiple times on the same project with no ill effect.

## Scope

In scope:

- Git repo detection and (with user confirmation) initialization on `main`.
- Project-mode detection (bringup vs protected) using the same heuristic
  as `end-session`, optionally augmented by a `gh api` branch-protection
  probe when `gh` is authenticated.
- Breadcrumb management in `CLAUDE.md` — write the bringup breadcrumb
  when in bringup mode, remove it when protected.
- Minimal `CLAUDE.md` scaffold when missing; ask the user for project
  purpose, stack, and notable conventions that can't be inferred from
  manifest files (`package.json`, `pyproject.toml`, `Cargo.toml`,
  `go.mod`, etc.). Leave an existing `CLAUDE.md` alone beyond the
  breadcrumb and PR-rules block.
- Minimal `README.md` scaffold when missing (title, one-line purpose,
  setup, usage). Leave existing `README.md` alone.
- Stamp a canonical PR-workflow rules block into `CLAUDE.md`, bracketed
  by HTML comment markers so re-runs can detect and update in place.
- Dependency-skill handling:
  - Auto-junction dev-setup-owned skills (`end-session`, `review-plan`)
    into `~/.claude/skills/` if missing.
  - Check plugin-sourced skills (`simplify`, `codex`, `superpowers`,
    `claude-md-management`) and print the exact `claude plugin install`
    commands for any that are missing; do not auto-install plugins.
- Final report to the user: mode detected, what was created or updated,
  what manual steps still need to happen.
- Self-improvement: fix clear bugs in the skill in place during
  execution, note them in the final report.

Out of scope:

- Deep `CLAUDE.md` audits. A separate invocation of
  `claude-md-management:claude-md-improver` is the right tool for that;
  the skill may suggest it in the final report but does not invoke it.
- Running `claude plugin install` on behalf of the user.
- Destructive git operations (force-push, reset, branch delete).
- Any action on `staging` / `prod` branches.

## Non-goals

- Not a replacement for `end-session`. `init-project` sets the project
  up; `end-session` wraps up work inside a session. They share the same
  project-mode detection and breadcrumb text so they stay consistent.
- Not a package manager. It does not install language toolchains,
  dependencies, or editor config — that is the project's own
  responsibility (or `ubuntu-debloat`'s, at the OS level).

## Architecture

```
.claude/skills/init-project/
├── SKILL.md                  # thin decision-tree body
├── README.md                 # plain-English overview + install intent
└── scripts/
    ├── lib.sh                # shared logging + idempotency helpers
    ├── detect-mode.sh        # prints "bringup" or "protected"
    └── install-dep-skill.sh  # junction a dev-setup skill into ~/.claude/skills/
.claude/commands/init-project.md  # thin slash-command wrapper
```

Install target: **user-level.** Junction
`dev-setup/.claude/skills/init-project` into `~/.claude/skills/init-project`
so `/init-project` is available in every project.

Indexes to update when the skill lands:

- `claude-skills.md` — add an `### init-project` entry.
- `README.md` (repo root) — add a row to the "Skills at a glance" table.

## SKILL.md shape

Frontmatter `description` (tight, specific enough to trigger reliably):

> Bring a project up to baseline: ensure it's a git repo on `main`,
> detect bringup vs protected mode and manage the breadcrumb
> accordingly, scaffold missing `CLAUDE.md`/`README.md`, stamp the
> PR-workflow rules block into `CLAUDE.md`, and verify required
> dependency skills are accessible (auto-junction dev-setup-owned
> skills, report missing plugins). Safe to re-run. Triggers:
> `/init-project`, "initialize this project", "set up this repo for
> Claude", "bring this project up to baseline".

Body sections (end-session shape — thin, decision-tree oriented):

1. Announce line: "Running /init-project to bring this project up to baseline."
2. Triggers list.
3. What this skill authorizes / does not authorize.
4. The flow (the nine steps below), each with a short action + check line.
5. Destructive operations — always ask (same list as `end-session`).
6. Self-improvement footer (same pattern as `end-session`).

## The flow

1. **Read the state.** `git rev-parse --git-dir`, `git remote get-url
   origin`, `git branch --list`, `git log --oneline -20`. Does
   `CLAUDE.md` exist? Does `README.md` exist?

2. **Git init (if needed).** No `.git` and the directory looks
   code-shaped (has source files or a manifest) → ask the user → `git
   init` and `git symbolic-ref HEAD refs/heads/main` so the default
   branch is `main`.

3. **Detect project mode** via `scripts/detect-mode.sh`. Heuristic:
   feature branches present OR PR/squash-merge history visible OR (when
   `gh auth status` is clean) `gh api
   repos/{owner}/{repo}/branches/main/protection` returns 200 →
   **protected**. Otherwise **bringup**. The script prints `bringup` or
   `protected` to stdout and exits 0 either way; it is silent when `gh`
   is unavailable.

4. **Breadcrumb management** in `CLAUDE.md`.
   - Bringup: ensure the `## Project Mode` breadcrumb block exists,
     with the same text `end-session` uses. Kept in sync by convention.
   - Protected: remove any existing bringup breadcrumb so it does not
     mislead future sessions.

5. **Ensure `CLAUDE.md` exists.** If missing, scaffold a minimal file
   (project name, one-line purpose, stack/framework notes, any
   non-obvious conventions). Infer what is inferrable from manifest
   files; ask the user for the rest. Then stamp the PR-workflow rules
   block (step 7).

6. **Ensure `README.md` exists.** If missing, scaffold a minimal
   human-facing README: title, one-line purpose, setup, usage. Ask for
   anything that can't be inferred.

7. **Stamp the PR-workflow rules block** into `CLAUDE.md`, idempotently.
   Bracket with HTML comment markers so re-runs detect the block and
   update it in place rather than duplicating. Block text:

   ```markdown
   <!-- init-project:pr-rules-start -->
   ## Pull Request Workflow

   **NEVER open a PR until all four are true:**

   1. Local branch is up to date with `origin` for both this branch
      and the target (`git fetch origin`).
   2. This branch is rebased onto the target (usually `main`) with no
      merge conflicts.
   3. Every CI gate that blocks merge has been run locally and passed —
      tests, typecheck, lint, and any project-specific checks listed
      in `.github/workflows/*.yml` or equivalent.
   4. The branch has been pushed to `origin` after the rebase.

   **PR defaults:** auto-merge enabled, squash merge. Title and body
   should come from the session summary or recent commits.

   If any of the four conditions isn't met, finish the prep first —
   don't open the PR.
   <!-- init-project:pr-rules-end -->
   ```

   Idempotency: grep for the start marker; if present, replace the
   block between markers; if absent, append the block.

8. **Dependency skills.** Two categories, handled differently.
   - **Auto-junction** (dev-setup-owned): `end-session`, `review-plan`.
     If `~/.claude/skills/<name>` is missing, invoke
     `scripts/install-dep-skill.sh <name>` to junction from
     `~/src/dev-setup/.claude/skills/<name>`. No-op if already linked.
   - **Check + report** (plugin-sourced): `simplify`, `codex`,
     `superpowers`, `claude-md-management`. Probe `~/.claude/plugins/`
     (and `claude plugin list` if available). For any missing, print
     the exact `claude plugin install <name>` command the user should
     run. Do not auto-install.

9. **Final report** to the user: mode detected, what was created or
   modified (`CLAUDE.md`, `README.md`, breadcrumb, PR-rules block),
   which dependency skills were auto-junctioned, which plugins are
   still pending for the user to install. If the skill self-patched a
   bug during execution, note it here.

## Helper scripts

- **`scripts/lib.sh`** — shared helpers.
  - `log_info` / `log_warn` / `log_ok` — consistent prefixed output.
  - `ensure_junction <target> <link>` — idempotently create a junction
    (Windows) or symlink (Linux/macOS). No-op if the link already
    points at the target; error if a file or wrong link exists at
    `<link>`.
  - `have_gh_auth` — exit 0 if `gh auth status` is clean, else 1.
  - All scripts source this file and use `set -euo pipefail`.

- **`scripts/detect-mode.sh`** — prints `bringup` or `protected` to
  stdout; always exits 0. Uses the heuristic described in step 3.

- **`scripts/install-dep-skill.sh <skill-name>`** — idempotently
  junctions `~/src/dev-setup/.claude/skills/<name>` to
  `~/.claude/skills/<name>` via `ensure_junction`. Errors if the source
  does not exist.

## Slash command wrapper

`.claude/commands/init-project.md` — same shape as
`.claude/commands/end-session.md`: frontmatter `description` line, a
short body that invokes the `init-project` skill and passes
`$ARGUMENTS` through. No logic of its own.

## Consistency with related skills

- **`end-session`** — shares the project-mode heuristic and breadcrumb
  text. When one is updated, check the other still agrees. The
  PR-workflow rules block stamped by `init-project` is the policy
  side; `end-session` step 13 ("Sync with origin") and step 14 ("Push
  and PR decision") are the enforcement side.
- **`review-plan`** — no direct dependency, but `init-project` ensures
  it is junctioned so it is available in the project.
- **`claude-md-management:claude-md-improver`** — not invoked, but
  `init-project`'s final report may suggest running it for a deeper
  audit of an existing `CLAUDE.md`.

## Testing

No formal test harness — this skill is script-driven and judgment-driven.
Validation is by running it against a matrix of starting states and
confirming idempotency:

- Fresh directory, no git, no docs → creates git, `CLAUDE.md`,
  `README.md`, bringup breadcrumb, PR-rules block, junctions missing
  dependency skills.
- Existing git repo on `main` with one commit, no docs → same as above
  minus the `git init`.
- Existing repo with feature branches and PR history, with a stale
  bringup breadcrumb → removes the breadcrumb, leaves docs alone
  (beyond refreshing the PR-rules block), reports mode as protected.
- Fully initialized repo (second run) → no-op except refreshing the
  PR-rules block if its content has drifted; report lists nothing
  changed.

## Self-improvement

When the skill notices a clear bug in itself during execution (wrong
command, broken logic, outdated reference), it fixes the issue in place
in `~/src/dev-setup/.claude/skills/init-project/` and notes the fix in
the final report. Judgment-call improvements are proposed, not applied.
Same pattern as `end-session`.
