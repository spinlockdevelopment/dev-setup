# create-gh-token

Mints a GitHub **fine-grained Personal Access Token** tailored to one
project, then wires it into the project's HTTPS git remote so pushes
work without a credential prompt.

The skill is question-driven: Claude asks four short questions
(should the token create repos? org-wide or single repo? which
sub-permissions? branch-protection plan?) and produces a concise
checklist for the GitHub PAT creation form. The user fills the form
in their browser as the GitHub admin ("master account"), pastes the
token back into the script, and the script does the rest.

If you read only this file, you'll be able to create the right token
yourself, understand exactly what each permission grants, and wire it
into your project — no Claude required.

## Glossary in 30 seconds

- **Master account** — the GitHub user account that owns the org or
  the repo you want the token to act on. You must be logged in as
  this account when you visit the PAT page.
- **Resource owner** — the user or org the token is scoped to.
  Fine-grained tokens only act on resources owned by this owner. Pick
  the org (or your personal account) the repo lives under.
- **Repository access** — "All repositories" (org-wide) or "Only
  select repositories" (a list you pick). For a single project, pick
  Only select and choose just that repo.
- **Repository permissions** — what the token can do inside the
  repos it has access to. The table below explains each one.
- **Organization permissions** — what the token can do at the org
  level (membership, billing, security alerts, etc.). Most tokens
  need only `Members: Read` if anything.
- **Account permissions** — what the token can do on the
  resource-owner's user/org profile itself. Almost always leave all
  on "No access".

## Step 1 — open the PAT creation page

While logged in as the **master account** (the user that admins the
org or owns the repo), open:

> https://github.com/settings/personal-access-tokens/new

If the org doesn't appear in the **Resource owner** dropdown, either
(a) you're not logged in as an org admin, or (b) the org has
fine-grained tokens disabled — fix in
`Org → Settings → Personal access tokens → Settings`.

## Step 2 — fill the form

| Field | What to enter |
|---|---|
| Token name | Anything you'll recognize. Convention: `<project>-<scope>`, e.g. `dev-setup-rw` or `myorg-rw-no-admin`. |
| Expiration | 30 / 60 / 90 days, or custom. GitHub does not allow "never" for fine-grained tokens. Pick what matches your rotation discipline. |
| Description | Why the token exists, who's using it, where it's stored. Helps future-you when GitHub's token list grows. |
| Resource owner | The org (or your user) that owns the repo. **Not** your personal account if the repo is in an org. |
| Repository access | "Only select repositories" + pick the repo, or "All repositories" if you want one token across the whole org. Avoid "Public repositories (read-only)". |

Then set permissions per the tables below.

## Step 3 — Repository permissions reference

Set these under **Repository permissions**. Anything not listed,
leave on **No access** — fine-grained tokens default safe.

| Permission | What it unlocks | What it blocks (still) | When you need it |
|---|---|---|---|
| **Metadata: Read** | Listing the repo, reading basic info (default branch, visibility). | Code, issues, anything beyond existence. | Always. Auto-set when you grant any other repo permission. |
| **Contents: Read and write** | `git fetch`, `git push`, branch create/delete, commit, file edits via API. | Repo deletion, branch protection edits, settings changes. | Always, if the token will push or pull. |
| **Contents: Read** | `git fetch` / `git clone` only. | Pushing. | Read-only mirrors, deploy pulls, CI checkouts. |
| **Administration: Read and write** | `POST /orgs/<org>/repos` (create repo), repo deletion, transfer, archive, branch-protection-rule edits, repo settings. | Org-level admin (members, billing). | Only if the token must create new repos. **Also unlocks deletion + protection edits — there is no narrower bit today.** Pair with branch protection or a ruleset (Step 5). |
| **Pull requests: Read and write** | Open / merge / close PRs, comment, request reviews. | Bypassing required reviews on protected branches. | Bots that open PRs, agents that merge their own work. |
| **Pull requests: Read** | List PRs, read diffs and comments. | Any change. | Read-only PR dashboards. |
| **Issues: Read and write** | Open / close / comment / label / assign issues. | Reading or modifying PRs (those are separate). | Issue-triage bots, agents that file bug reports. |
| **Workflows: Read and write** | Create / modify `.github/workflows/*.yml` files via the API or via push. | Triggering or cancelling runs (that's Actions). | Pushing changes to workflow files. **Without this, a push that touches `.github/workflows/` is rejected even if Contents:RW is set.** |
| **Actions: Read and write** | Trigger workflow_dispatch runs, cancel runs, manage workflow run artifacts and logs. | Editing workflow YAML (that's Workflows). | Bots that re-run failed jobs, kick off deploys. |
| **Pages: Read and write** | `POST /repos/<o>/<r>/pages` to enable/configure GitHub Pages, change source branch, set custom domain. | Pushing site content (that's Contents). | First-time Pages enablement via API; most projects don't need it after the initial setup. |
| **Secrets: Read and write** | Create/update Actions or Dependabot secrets via API. | Reading secret values (write-only by design). | CI bootstrap automations. Rare. |
| **Variables: Read and write** | Create/update Actions variables. | Nothing else. | CI bootstrap automations. Rare. |
| **Deployments: Read and write** | Create / mark deployments as success/failure. | Performing the actual deploy. | Custom deploy bots that report status back to GitHub. |
| **Environments: Read and write** | Manage environment protection rules, environment secrets/variables. | Bypassing environment approvals. | Setting up new environments via API. Rare. |
| **Webhooks: Read and write** | Create / update / delete repo-level webhooks. | Org-level webhooks (that's an org permission). | Setting up integrations. Rare. |

### Recommended starter set

For an agent that will push code, open PRs, and react to issues in
**one existing repo**:

```
Metadata           Read              (auto-set)
Contents           Read and write    (push/pull)
Pull requests      Read and write
Issues             Read and write
Workflows          Read and write    (so workflow file edits push successfully)
Actions            Read and write    (so the agent can re-run jobs)
```

Add **Pages: Read and write** if the project has a Pages site you'll
be (re)configuring. Add **Administration: Read and write** only if
the token must create new repos — and read Step 5 first.

## Step 4 — Organization permissions reference

Only relevant if Resource owner = an org. Most tokens need none of
these. The two that occasionally come up:

| Permission | What it unlocks | When you need it |
|---|---|---|
| **Members: Read** | Resolving usernames, listing org members in API responses. | Any time you `gh api /orgs/<org>/members` or use a CLI that does. |
| **Administration: Read and write** | Org settings, deleting the org. | Almost never. Avoid. |

Leave everything else on **No access**.

## Step 5 — branch protection (the real guardrail)

Fine-grained PATs can't be scoped narrower than `Administration:
Read and write` for repo creation, and the same bit grants deletion
and the ability to **disable branch protection rules**. So the token
itself isn't the safety net — branch protection / rulesets are.

Pick one of three:

### Option A — org-level ruleset (best, requires GitHub Team)

One rule covers every current and future repo. Run **once per org**
from any shell where `gh` is logged in:

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

`bypass_actors: []` means **no one bypasses** — including the org
owner with this PAT. To intentionally force-push later, you have to
disable the ruleset in
`Org → Settings → Rules → protect-release-branches` first (two
deliberate clicks instead of one accidental command).

If the API responds "Upgrade to GitHub Team", the org is on Free or
classic Pro and this option isn't available. Use B or C.

### Option B — per-repo branch protection (UI, works on every plan)

In each repo: `Settings → Branches → Add branch protection rule`,
applied to `main` (and `staging` / `prod` once they exist):

- [x] Require a pull request before merging
- [x] Require status checks to pass before merging  *(optional)*
- [x] Require conversation resolution before merging *(optional)*
- [x] Do not allow bypassing the above settings  ← **critical**
- [ ] Allow force pushes  ← **leave unchecked**
- [ ] Allow deletions     ← **leave unchecked**

### Option C — no protection (small / throwaway projects)

Acceptable for personal scratch repos. **Not** acceptable when the
token has `Administration: Read and write` — accidental
`gh repo delete` or `git push --force` rewrites history with no
undo. If you go this route, prefer to keep `Administration` off
(don't use the token for repo creation).

## Step 6 — wire the token into the project

Run from inside the project directory:

```bash
./scripts/create-gh-token.sh
```

The script:

1. Detects the git repo and parses `<owner>/<repo>` from `origin`.
2. Prompts for the token (input hidden).
3. Validates against `https://api.github.com/user` and
   `https://api.github.com/repos/<owner>/<repo>` — fails fast if the
   token doesn't actually have access to this repo.
4. Rewrites `origin` to
   `https://x-access-token:<TOKEN>@github.com/<owner>/<repo>.git`.
5. Confirms with `git ls-remote origin`.

Modes:

```bash
./scripts/create-gh-token.sh                  # interactive, default
./scripts/create-gh-token.sh --remote upstream  # rewrite a non-origin remote
./scripts/create-gh-token.sh --no-set-remote    # validate only, leave remote alone
./scripts/create-gh-token.sh --verify           # check the current remote works
```

The token lives **only** in `.git/config` (local to your checkout,
never pushed). A fresh `git clone` of the same repo elsewhere on
your machine will not carry it — re-run the script there.

## Security notes

- `.git/config` is owner-readable on most boxes; on a multi-user
  system, treat it like any other secret-bearing file. You can
  `chmod 600 .git/config` after the script runs, but be aware that
  occasionally breaks tools that expect 644.
- Prefer per-project tokens with **Only select repositories** — a
  leaked token then exposes one repo, not your whole org.
- Rotate by re-running the script with a fresh token. It overwrites
  the remote URL in place. Then revoke the old token at
  https://github.com/settings/personal-access-tokens.
- If you ever need to *remove* a token from a remote, rewrite the
  URL back to the unauthenticated form:
  `git remote set-url origin https://github.com/<owner>/<repo>.git`.
- Never commit `.env` files or scripts that echo the token. The
  script never prints the token to stdout.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `token rejected by GitHub` | Wrong token, expired, revoked, or copied with whitespace. | Re-paste; check expiration at the GitHub PAT page. |
| `403 Resource not accessible by personal access token` on push | Repo isn't in the token's selected repositories list, or `Contents` is not Read+write. | Edit the token at the GitHub PAT page → add the repo / fix the permission. |
| Push to `.github/workflows/*.yml` rejected with `refusing to allow a Personal Access Token to create or update workflow` | Token is missing `Workflows: Read and write`. | Add the permission. |
| `gh api` ruleset call returns "Upgrade to GitHub Team" | Org is on Free or classic Pro. | Use Option B (per-repo branch protection). |
| `git ls-remote` works but actual `git push` prompts for a password | Some other helper (Keychain, libsecret) is intercepting. | `git config --local credential.helper ""` inside the repo to disable helpers; the embedded URL token will then be used. |

## More

- Claude-facing decision tree (so the skill auto-asks the four
  questions): [`SKILL.md`](./SKILL.md)
- Catalog entry: [`claude-skills.md`](../../../../claude-skills.md)
- Inspiration / older bespoke version: `bootstrap/github-pat.sh` in
  `~/src/tod.smith` — org-specific, prescriptive. This skill is the
  generalized, project-scoped successor.
