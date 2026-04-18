---
name: gh
description: Use when creating or managing GitHub repos, fine-grained PATs, branch protection, or org rulesets. Trigger on any mention of GitHub org setup, repo creation, PAT rotation, force-push protection, branch rules, rulesets, "Resource not accessible by personal access token", or branch-protection-vs-ruleset decisions on Free/Team plans.
---

# gh — GitHub org + repo operations

Playbook for provisioning and managing GitHub orgs, fine-grained PATs,
and branch protection. Organized as a decision tree — pick your path,
follow the linked script.

## When to use this skill

- Creating a new org or setting up an existing one for safe agent use.
- Generating a fine-grained PAT with correct guardrails.
- Creating org repos with `gh` or the REST API.
- Protecting `main` / `staging` / `prod` from force-push and deletion.
- Resolving the "Resource not accessible by personal access token" 403.
- Deciding between legacy branch protection and rulesets.

## Decision tree

### 1. PAT setup

**Fine-grained PAT (preferred).** Classic PATs are all-or-nothing with
`repo` scope — can delete repos, modify branch protection,
everything. Fine-grained lets you split some capabilities.

Key insight, often missed: `POST /orgs/{org}/repos` requires
**Repository permissions → Administration → Read and write**, NOT
Organization Administration. GitHub files the endpoint under
Repository Administration despite the URL path starting with
`/orgs/`. With Repo Admin write, the PAT can also delete repos and
modify branch protection — there is no narrower bit today.

See `scripts/bootstrap-pat.sh` for an interactive walkthrough that
opens the form with the correct permission list inline.

### 2. Org repo creation

With the PAT above:

```bash
gh api -X POST /orgs/<org>/repos \
  -f  name=<repo> \
  -F  private=true \
  -F  auto_init=true \
  -f  default_branch=main \
  -F  has_issues=true \
  -F  has_projects=false \
  -F  has_wiki=false
```

Idempotent wrapper: `scripts/create-repo.sh <org> <repo> [--public]`.

### 3. Branch protection — which mechanism?

Two overlapping mechanisms. Plan matters:

| Plan | Private repo | Public repo |
|---|---|---|
| Free for Orgs | NONE available | Rulesets work |
| Pro (personal only) | Rulesets on user-owned | Rulesets |
| **Team** (org) | **Rulesets (repo & org level)** | Rulesets |
| Enterprise | Rulesets + legacy branch protection | both |

Legacy branch protection is deprecated; rulesets are the future.
On a private-repo org, you need **Team** ($4/user/month) to use
rulesets at all. Free-plan orgs have no mechanical guardrail
available — discipline-only.

### 4. Ruleset — the good default

Org-level ruleset that protects `main`/`staging`/`prod` across every
repo (including future ones), blocks force-push + deletion, requires
PR. No bypass actors = even the org owner can't force-push without
disabling the rule first.

See `scripts/apply-org-ruleset.sh` for the exact JSON body that
worked in production. Resolves the "Upgrade to GitHub Team" 403 at
the verify step.

### 5. "Resource not accessible by personal access token" — 403 triage

Causes in order of likelihood:

1. **Missing fine-grained permission.** Read the endpoint's entry in
   [the permissions reference](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens).
   Many endpoints on `/orgs/` URLs require repository-level
   permissions.
2. **Org hasn't enabled fine-grained PATs.** Org settings → Personal
   access tokens → Fine-grained PATs → Allow access.
3. **PAT requires owner approval** (if the org policy is set to
   "approval required"). Check org settings → PAT requests.
4. **Resource owner mismatch.** The PAT was created targeting your
   user account instead of the org. Rotate via `bootstrap-pat.sh
   --rotate`.

Probe the token's actual permissions with
`scripts/probe-token.sh` — exercises a range of endpoints and
surfaces which permission bits are granted.

## Scripts

- `scripts/bootstrap-pat.sh` — interactive fine-grained PAT creation
  with correct permission guidance; stores at
  `~/.config/<project>/secrets/` with chmod 600; logs into `gh` via
  `gh auth login --with-token`.
- `scripts/create-repo.sh <org> <repo>` — idempotent org-repo creation.
- `scripts/apply-org-ruleset.sh <org>` — create or update the
  `protect-release-branches` ruleset (no force-push, no deletion,
  PR required) on the org. Fails with the "Team required" message
  on Free plan.
- `scripts/probe-token.sh` — exercises a PAT against read/write
  endpoints and prints a capability report. Safe — no destructive
  ops.

## Self-healing

If this skill's scripts reference paths or permission names that
GitHub has renamed, update in place from the authoritative reference
page. When the permissions model shifts (rare but it happens), update
the decision tree and the scripts' printed instructions together.
