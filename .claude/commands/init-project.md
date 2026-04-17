---
description: Bring this project up to baseline for working with Claude — git init (if needed), mode breadcrumb, minimal CLAUDE.md / README.md, PR-workflow rules block, dependency skills
---

Invoke the `init-project` skill to bring this project up to baseline — ensure it's a git repo on `main`, detect bringup vs protected mode and manage the breadcrumb, scaffold missing `CLAUDE.md` / `README.md`, stamp the canonical PR-workflow rules block into `CLAUDE.md`, auto-junction dev-setup-owned dependency skills (`end-session`, `review-plan`) into `~/.claude/skills/`, and report any missing plugin skills with install commands. Safe to re-run.

Arguments: $ARGUMENTS
