---
description: Mirror the repo's PR auto-review CI locally before push — gitleaks + shellcheck + script conventions + a Claude PII/secrets/structural pass over the current branch's diff
---

Dispatch the `pr-prepass` subagent against the current working tree. It will read `.github/workflows/pr-review.yml` (if present) and mirror each step locally, then return a structured findings report. Do not push or open a PR — `pr-prepass` reports only; the operator decides what to fix.

If a base/head ref or diff range is needed, pass it after the command. Otherwise the agent defaults to `main...HEAD`.

Arguments: $ARGUMENTS
