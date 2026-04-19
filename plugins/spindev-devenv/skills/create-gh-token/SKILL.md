---
name: create-gh-token
description: Walk the user through minting a fine-grained GitHub Personal Access Token tailored to one project, then wire it into the project's git remote so HTTPS pushes work without prompting. Asks four short questions (create-repos? org-wide vs select repos? which sub-permissions? branch protection plan?), prints a concise PAT-creation checklist tuned to the answers, then runs a script that validates the pasted token and rewrites the remote URL. Use when the user says "set up a github token", "create a PAT for this project", "I need a GitHub token to push", "let claude push from this repo", "wire a github token into this project", or any phrasing about giving an agent push access to a repo.
---

# create-gh-token

Mint a fine-grained PAT tailored to one project and wire it into the
project's HTTPS remote URL. Token never leaves the user's machine.

Real work is in `scripts/create-gh-token.sh`. This file is the
question flow + permission-mapping decision tree.

## Decision tree

### Step 1 — ask the user (use AskUserQuestion if available)

Keep it to four questions. Default answers in **bold**.

1. **Create repos?** — "Should this token be able to create new repos
   under an org?"
   - Yes (include `Administration: Read and write`) — required for
     `POST /orgs/<org>/repos`. **Also grants delete + branch-protection
     edit; there is no narrower bit today.**
   - **No** (omit Administration) — token can only push/pull existing
     repos.
2. **Scope?** — "All repos in an org, or only specific repos?"
   - All in org `<name>` — Resource owner = org, Repository access =
     All repositories. Ask for the org name.
   - **Specific repo(s)** — Resource owner = org or personal,
     Repository access = Only select repositories. Default to *just
     this project's repo* (parse from `git remote get-url origin`).
3. **Sub-permissions?** — "Beyond Contents (push/pull), which APIs do
   you need? Issues / Pull requests / Workflows / Actions / Pages."
   - **All on by default.** Most projects want all five. User can
     deselect any they're sure they don't need.
4. **Branch protection plan?** — "Will you protect `main` (and any
   other release branches) so the token can't force-push or delete?"
   - **Yes — org-level ruleset** (recommended if user has a GitHub
     Team plan and >1 repo). Print the inline `gh api` snippet from
     the appendix below.
   - Yes — per-repo branch protection (UI checklist). Print the
     checklist.
   - No protection — print a one-line warning explaining the blast
     radius (esp. if Q1 was Yes), then continue.

If Q1 = No AND Q4 = No, skip the warning — the token can still
force-push to branches it has Contents:RW on, but can't delete repos
or rewrite protected-branch settings.

### Step 2 — print the PAT creation checklist

Build the permissions block from the answers. Always include:
- Repository → **Metadata: Read** (auto-set, required)
- Repository → **Contents: Read and write** (push/pull)

Add per the answers:

| If user said… | Add to Repository permissions |
|---|---|
| Q1 = Yes | Administration: Read and write |
| Q3 includes Issues | Issues: Read and write |
| Q3 includes PRs | Pull requests: Read and write |
| Q3 includes Workflows | Workflows: Read and write |
| Q3 includes Actions | Actions: Read and write |
| Q3 includes Pages | Pages: Read and write |

Plus:
- If Q2 = org: Organization → **Members: Read** (lets the token
  resolve usernames in collaborator/PR APIs).
- Token name suggestion: `<project-or-org>-<scope>` e.g.
  `dev-setup-rw` or `myorg-rw-no-admin`.

Tell the user to:
1. Open https://github.com/settings/personal-access-tokens/new while
   logged in as the **account that owns the repo / has admin on the
   org** ("master account").
2. Fill in the form per the checklist.
3. Click "Generate token" and copy it (shown once).
4. Come back and paste it into the script when prompted.

### Step 3 — run the script

```bash
./scripts/create-gh-token.sh
```

The script runs from the project root, reads the pasted token
silently, validates it against `/user` and against the project's
repo, and rewrites `origin` (or `--remote <name>`) to embed the
token. Token is stored only in `.git/config` (local, not pushed).

If the user wants to validate without rewriting: `--no-set-remote`.
If the user wants to check an already-wired remote:
`--verify`.

### Step 4 — apply the chosen branch protection (if Q4 said yes)

If Q4 = "org-level ruleset", run this once per org:

```bash
ORG=<org-name>
gh api -X POST "/orgs/${ORG}/rulesets" \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON'
{
  "name": "protect-release-branches",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH", "refs/heads/staging", "refs/heads/prod"],
      "exclude": []
    },
    "repository_name": { "include": ["~ALL"], "exclude": [], "protected": false }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge", "squash", "rebase"]
      }
    }
  ]
}
JSON
```

Requires GitHub Team or higher (rulesets are gated on private repos).
If it fails with "Upgrade to GitHub Team", fall back to per-repo
branch protection in the UI.

If Q4 = "per-repo UI", print this checklist for the user to apply
manually under Settings → Branches → Add rule on each protected
branch:

- [x] Require a pull request before merging
- [x] Do not allow bypassing the above settings
- [ ] Allow force pushes  ← **leave unchecked**
- [ ] Allow deletions     ← **leave unchecked**

## Output style

Be concise. The whole interaction is: 4 questions → checklist (~15
lines) → run script → optional ruleset command. Don't restate
GitHub's docs; the script handles validation and tells the user when
something's off.

## Self-improvement

This skill is served from a read-only plugin cache
(`~/.claude/plugins/cache/spindev-devenv@spinlockdevelopment/<version>/`).
Edits there don't persist. Edit the authoritative copy at
`plugins/spindev-devenv/skills/create-gh-token/` in a clone of
`spinlockdevelopment/dev-setup`, commit (bringup: straight to `main`;
protected: feature branch + PR), push.

**Triggers for self-update:**

- GitHub renames the fine-grained PAT page
  (currently https://github.com/settings/personal-access-tokens/new)
  → fix the URL in this file and in `scripts/create-gh-token.sh`.
- GitHub adds a permission narrower than `Administration: Read and
  write` that grants `POST /orgs/<org>/repos` *without* delete /
  branch-protection edit → loosen the Q1=Yes warning and the
  permission table.
- The fine-grained PAT prefix changes from `github_pat_` → update the
  format check in the script.
- `gh api /orgs/<org>/rulesets` request shape changes → update the
  inline ruleset JSON above.
