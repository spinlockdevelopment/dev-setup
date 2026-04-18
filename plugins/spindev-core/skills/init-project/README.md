# init-project

Bring any project up to a baseline state for working with Claude. Safe to run on the same project repeatedly — every action is idempotent.

## What it does

- Ensures the project is a git repo with `main` as the default branch (running `git init` only after user confirmation).
- Detects **bringup** vs **protected** mode using the same heuristic as `end-session` (feature branches, squash-merge history, optional `gh api` branch-protection probe).
- Writes a `## Project Mode` breadcrumb in `CLAUDE.md` when in bringup mode; removes it when protected.
- Scaffolds a minimal `CLAUDE.md` and `README.md` if either is missing, asking the user only for details it can't infer from manifest files.
- Stamps a canonical **Pull Request Workflow** rules block into `CLAUDE.md`, idempotently, bracketed by HTML comment markers so re-runs update in place rather than duplicate.
- Junctions dev-setup-owned dependency skills (`end-session`, `review-plan`) into `~/.claude/skills/` if they aren't already.
- Reports any plugin-sourced dependency skills (`simplify`, `codex`, `superpowers`, `claude-md-management`) that are missing, with the exact install command to run.

## Why it exists

Every new or freshly-cloned project needs the same baseline before Claude can work in it comfortably: a git repo, a `CLAUDE.md`, a README, the PR rules, the wrap-up skill. Doing it by hand every time is error-prone and noisy. This skill folds all of that into one idempotent entry point.

## Trigger

- `/init-project` — the slash-command wrapper
- Phrases: "initialize this project", "set up this repo for Claude", "bring this project up to baseline"

## Installation intent

**User-level.** Junction this skill into `~/.claude/skills/` so `/init-project` works in every project.

### Windows

```bash
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 cmd.exe /c mklink /J \
  'C:\Users\<you>\.claude\skills\init-project' \
  'C:\Users\<you>\src\dev-setup\.claude\skills\init-project'
```

### Linux / macOS

```bash
ln -s ~/src/dev-setup/.claude/skills/init-project ~/.claude/skills/init-project
```

Verify the link is real (not a copy) — on Windows, `cmd //c dir ~/.claude/skills/` should show `<JUNCTION>` next to `init-project`.
