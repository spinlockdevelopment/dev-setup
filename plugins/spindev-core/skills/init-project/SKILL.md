---
name: init-project
description: Bring a project up to baseline for working with Claude — ensure it's a git repo on `main`, detect bringup vs protected mode and manage the breadcrumb accordingly, scaffold missing `CLAUDE.md`/`README.md`, stamp the canonical PR-workflow rules block into `CLAUDE.md`, auto-junction dev-setup-owned dependency skills (`end-session`, `review-plan`) into `~/.claude/skills/`, and report missing plugin skills (`simplify`, `codex`, `superpowers`, `claude-md-management`) with install commands. Safe to re-run. Triggers: `/init-project`, "initialize this project", "set up this repo for Claude", "bring this project up to baseline".
---

# /init-project

Bring a project up to baseline for working with Claude. Idempotent — every action checks current state first and no-ops when the project already matches baseline. Safe to run repeatedly.

Announce at start: "Running /init-project to bring this project up to baseline."

## Triggers

- `/init-project` (slash command)
- Phrases: "initialize this project", "set up this repo for Claude", "bring this project up to baseline"

## What this skill authorizes

- Create or edit `CLAUDE.md` and `README.md` in the target project
- Run `git init` (only after user confirmation)
- Junction dev-setup-owned skills into `~/.claude/skills/`
- Write or remove the `## Project Mode` breadcrumb in `CLAUDE.md`
- Stamp the PR-workflow rules block into `CLAUDE.md`

It does **not** authorize:
- Destructive git ops (force-push, `reset --hard`, `branch -D`) — always ask
- Running `claude plugin install` on the user's behalf — print the command, let them run it
- Deep rewrites of existing `CLAUDE.md` / `README.md` — beyond the breadcrumb and PR-rules block, leave them alone

## The flow

Walk these in order. Announce the current step. Skip steps that clearly do not apply and say so.

### 1. Read state

- `git rev-parse --git-dir` — is this a git repo?
- `git remote get-url origin` — any remote?
- `git branch --list` and `git log --oneline -20` — any feature branches, squash-merge history?
- Does `CLAUDE.md` exist? Does `README.md` exist?
- Manifest files present (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, etc.)? Use them to infer stack.

### 2. Git init (if missing)

No `.git` and the directory looks code-shaped (source files or manifest present) → ask the user, then:

```bash
git init
git symbolic-ref HEAD refs/heads/main
```

If the user declines, continue with the docs and dependency steps anyway.

### 3. Detect project mode

Run `scripts/detect-mode.sh` — prints `bringup` or `protected`.

Heuristic (matches `end-session`):
- Feature branches exist, OR
- PR / squash-merge history visible in `git log`, OR
- `gh api repos/{owner}/{repo}/branches/main/protection` returns 200 (only if `gh auth status` is clean)

→ **protected**. Otherwise **bringup**.

### 4. Breadcrumb management in `CLAUDE.md`

- **Bringup**: ensure this block exists under a `## Project Mode` heading:

  > **Bringup.** Commits go straight to `main`, no feature branches, no PR workflow yet. Promote to protected mode (and remove this breadcrumb) when the first feature branch + PR lands.

- **Protected**: remove any existing bringup breadcrumb.

### 5. Ensure `CLAUDE.md` exists

If missing, create a minimal file. Infer what you can from manifest files; ask the user for:
- Project purpose (one line)
- Stack/framework if not obvious from manifests
- Any notable conventions the user wants recorded

A minimal starting `CLAUDE.md` (scope + mode + PR rules block) is enough. Do not pad with generic advice. If `CLAUDE.md` already exists, leave its body alone — only manage the breadcrumb (step 4) and the PR-rules block (step 7).

### 6. Ensure `README.md` exists

If missing, create a minimal human-facing README: title, one-line purpose, setup, usage. Ask for anything not inferrable. If it exists, leave it alone.

### 7. Stamp the PR-workflow rules block into `CLAUDE.md`

Idempotent — bracketed by HTML comment markers. On re-run, replace the block between markers if present; otherwise append.

```markdown
<!-- init-project:pr-rules-start -->
## Pull Request Workflow

**NEVER open a PR until all four are true:**

1. Local branch is up to date with `origin` for both this branch and the target (`git fetch origin`).
2. This branch is rebased onto the target (usually `main`) with no merge conflicts.
3. Every CI gate that blocks merge has been run locally and passed — tests, typecheck, lint, and any project-specific checks listed in `.github/workflows/*.yml` or equivalent.
4. The branch has been pushed to `origin` after the rebase.

**PR defaults:** auto-merge enabled, squash merge. Title and body should come from the session summary or recent commits.

If any of the four conditions isn't met, finish the prep first — don't open the PR.
<!-- init-project:pr-rules-end -->
```

### 8. Dependency skills

Two categories, handled differently.

**Auto-junction (dev-setup-owned):** `end-session`, `review-plan`. For each, if `~/.claude/skills/<name>` doesn't already point at `~/src/dev-setup/.claude/skills/<name>`, run:

```bash
scripts/install-dep-skill.sh <name>
```

**Check + report (plugin-sourced):** `simplify`, `codex`, `superpowers`, `claude-md-management`. Probe `~/.claude/plugins/` for each; for any missing, print the install hint for the user to run. Do not auto-install. If the exact CLI for installing a plugin has changed, detect at runtime (`claude --help`, `claude plugin --help`) and print whatever form the installed `claude` supports.

### 9. Final report

One short message summarizing:
- Mode detected (bringup / protected)
- What was created or modified (`CLAUDE.md`, `README.md`, breadcrumb, PR-rules block)
- Which dependency skills were auto-junctioned
- Which plugin skills are still missing and the exact command to install each
- If the skill self-patched a bug during execution, note it

## Destructive operations — always ask

Always pause and confirm before:
- `git reset --hard`, `git clean -fd`, `git branch -D`, `git push --force`
- Removing or overwriting files the user has not confirmed

## Not a replacement for

- **`end-session`** — sets up vs wraps up. Share the same breadcrumb text and mode heuristic.
- **`claude-md-management:claude-md-improver`** — `init-project` does not audit existing `CLAUDE.md`; suggest `claude-md-improver` in the final report if the user wants a deeper pass.

## Self-improvement

If you notice a clear bug in this skill during execution — wrong command, broken path, reference to something that no longer exists — fix it in place at `~/src/dev-setup/.claude/skills/init-project/` and note the fix in the final report. Judgment-call improvements: describe and ask before editing.
