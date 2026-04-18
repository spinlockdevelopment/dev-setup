# gh — GitHub org + repo ops

Human-facing overview of this skill.

## What it is

A decision-tree skill + helper scripts for setting up GitHub
organizations safely: fine-grained PATs with correct guardrails, org
repo creation, branch protection via rulesets (Team plan), and
triage for the "Resource not accessible by personal access token"
403.

## Why it exists

Every rule in `SKILL.md` traces to a real finding. Specifically:

- The POST /orgs/{org}/repos endpoint requires **Repository**
  Administration write, not Organization Administration. Easy to
  miss; produces an uninformative 403.
- On GitHub Free (for orgs), private repos cannot use either legacy
  branch protection OR rulesets — you need Team. There is no
  in-between plan.
- Fine-grained PATs cannot distinguish "create repo" from "delete
  repo / change protection" — the permission bit is shared. The
  practical guardrail is the ruleset, not the token scope.

The scripts and inline guidance here bake those findings in so the
next time around takes 10 minutes instead of 2 hours.

## What it does

Interactive scripts that walk you through:

1. Creating a fine-grained PAT with the exact permission set that
   works (including the not-obvious Repo-Admin-write-or-nothing
   tradeoff).
2. Creating private repos in an org.
3. Applying a single org-level ruleset that protects
   `main`/`staging`/`prod` across every current and future repo.
4. Probing a PAT to see what it can actually do.

## Installation intent

**User-level** via the plugin marketplace at
`spinlockdevelopment/dev-setup`. No per-project install — once the
plugin is added, every Claude session sees this skill.

```bash
/plugin marketplace add spinlockdevelopment/dev-setup
/plugin install spindev-core
```

## Entry points

- `SKILL.md` — the decision tree Claude follows.
- `scripts/bootstrap-pat.sh` — interactive PAT creation.
- `scripts/create-repo.sh` — org repo creation.
- `scripts/apply-org-ruleset.sh` — ruleset application.
- `scripts/probe-token.sh` — token capability probe.

All scripts support `--verify` for read-only checks.
