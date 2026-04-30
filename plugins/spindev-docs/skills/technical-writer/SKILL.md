---
name: technical-writer
description: Scan an entire repository and publish a coherent mkdocs-formatted design doc (mkdocs-material theme) ready to deploy to GitHub Pages — or to any static host that consumes mkdocs `site/` output (Cloudflare Pages, Netlify, plain artifact). Delta-aware on rerun: consults a per-repo state file (last documented commit) and either incrementally updates only the pages whose source files changed, or full-regenerates if the delta is too disruptive (rebase/force-push/branch-swap detected, or breadth/depth too large to merge cleanly). Use when the user asks to "document this repo", "regenerate the design doc", "publish docs to gh-pages", "scaffold mkdocs for this project", or pairs an `/init-project` baseline with a docs site. Companion command `/docs-deploy` scaffolds an opt-in GitHub Pages workflow.
---

# technical-writer — repo-aware design doc generator

Thin skill. Real work lives in `scripts/` and `templates/`. You orchestrate
preflight → scan → delta decision → write/update → secrets pass → validate
→ record state. The per-page write step is the LLM (you), not a script.

Pairs naturally with `init-project` (after baseline) and `end-session`
(rerun on doc-relevant commits before wrapping up). Output is plain
mkdocs — the GH Pages workflow is opt-in via `/docs-deploy`.

## Decision tree

### 1. "document this repo" / first run

```bash
scripts/run-all.sh
```

`run-all.sh` orchestrates:

1. `preflight.sh` — confirm `git`, `mkdocs`, `pipx`. Install mkdocs +
   mkdocs-material via `pipx` if missing and `pipx` is available; if
   `pipx` is missing, print `sudo apt install -y pipx` for the user
   to run with the bang-prefix and bail.
2. `state.sh read` — load any prior state for this repo. First run has
   none.
3. `scan-repo.sh` — emit a JSON inventory of the repo (top-level
   layout, language census, manifests, entrypoints, deploy artifacts,
   README/CONTRIBUTING/CHANGELOG presence). You consume this.
4. `scaffold-mkdocs.sh` — materialize `mkdocs.yml` + the `docs/`
   skeleton from `templates/`. **If `docs/` already exists and is
   not a mkdocs site**, the skeleton goes in `design-docs/` and
   `mkdocs.yml` is configured with `docs_dir: design-docs`.
   Idempotent — never overwrites an existing `mkdocs.yml`.
5. **You write the pages.** From the scan, decide which template
   sections actually fit this repo. Skip a section entirely (drop
   from `nav:` too) if its source surface is empty. Use the
   templates in `templates/` as starting prose, replace placeholders.
6. **Secrets/PII pass.** Before writing each page to disk, do a
   careful read of the prose for accidental leakage: real-looking
   secrets paraphrased from `.env.example`, internal URLs, customer
   names, tokens that snuck out of code comments. Block writes on
   findings; report and let the operator decide. Mirrors the Claude
   pass in `pr-prepass`.
7. `build-docs.sh --verify` — runs `mkdocs build --strict`.
   Validates broken nav, missing pages, malformed YAML.
8. `state.sh write $HEAD_SHA` — record the documented commit + run
   timestamp + page list to the per-repo state file.

### 2. "regenerate the design doc" / rerun

Same entry: `scripts/run-all.sh`. The orchestrator reads state, asks
git for the diff since last run, and you decide:

- **No diff** → no-op; only refresh `last_run_iso`.
- **Linear diff (`merge-base --is-ancestor` is true)** → enumerate
  changed files via `git diff --name-only $LAST..HEAD`, decide
  page-by-page whether to incrementally edit or regenerate. **You
  (the LLM) make the call** — there is no hardcoded threshold.
- **Non-linear diff (rebase / force-push / branch swap detected)** →
  fall back to full regen, log the reason in the run report.

To force a full regen regardless: `scripts/run-all.sh --full-regen`.

### 3. "is this still up to date?" / quick check

```bash
scripts/run-all.sh --verify
```

Read-only. Reports: tooling presence, state file presence, commits
behind HEAD, pages currently in `nav:`. Writes nothing.

### 4. "publish to GitHub Pages" / wire the deploy

```bash
scripts/deploy-gh-pages.sh
```

Drops `templates/deploy-mkdocs.yml.tmpl` into the consumer repo at
`.github/workflows/deploy-mkdocs.yml`. Idempotent. Prints next steps
(GitHub → Settings → Pages → Source: GitHub Actions; push to
`main`). Modern split — uses `actions/upload-pages-artifact@v3` +
`actions/deploy-pages@v4`; no `gh-pages` branch.

The slash command `/docs-deploy` is a thin wrapper around this.

### 5. other static hosts (Cloudflare Pages, Netlify, plain artifact)

`scripts/build-docs.sh` runs `mkdocs build` and produces `site/`.
Point Cloudflare Pages / Netlify at that directory. No special
support needed — mkdocs output is portable.

## State file

Per-repo state at:

```
${HOME}/.local/state/technical-writer/repos/<repo-key>.json
```

`<repo-key>` is `sha256(remote.origin.url || git rev-parse --show-toplevel)`
truncated to 16 chars. Index file at
`${HOME}/.local/state/technical-writer/index.json` maps keys → human
paths.

The state file holds: `last_commit`, `last_run_iso`, `doc_root`
(`docs/` or `design-docs/`), `mkdocs_config`, `pages_generated`,
`tool_versions`. See `scripts/state.sh` for the full shape.

## Output layout

| Path in consumer repo | When |
|---|---|
| `mkdocs.yml` | Always (root). Theme: `material`. Nav written from `pages_generated`. |
| `docs/` | First run, when `docs/` is free. |
| `design-docs/` | First run, when `docs/` is already populated by something else (Sphinx, mdBook, plain markdown). `docs_dir: design-docs` in mkdocs.yml. |
| `.github/workflows/deploy-mkdocs.yml` | Only when `/docs-deploy` is run. |
| `site/` | Build output. **Do not commit** — add to `.gitignore` (the scaffold script does this). |

## Adaptive page menu

Don't slavishly emit every template. Pick from this menu based on what
`scan-repo.sh` actually finds:

| Page | Materialize when |
|---|---|
| `index.md` | Always. Landing page. |
| `architecture.md` | More than one top-level module / package / service. |
| `components.md` | Component count is non-trivial. |
| `data-flow.md` | Scan finds queues, DBs, message brokers, cross-service calls. |
| `deployment.md` | Deploy artifacts present (Dockerfile, fly.toml, k8s manifests, deploy GH workflow). |
| `operations.md` | Ops surfaces present (runbooks, alert configs, SLOs). |
| `development.md` | README/CONTRIBUTING + at least one manifest (package.json, pyproject.toml, etc.). |
| `glossary.md` | Domain-specific terms emerged that a newcomer would miss. |

**Rule:** never emit an empty stub. If a section would have nothing
to say, drop it from `nav:` too. A short site is better than a
padded one.

## Reporting

End each run with a tight report:

```
## technical-writer — <repo>:<head>

State: <last_commit> → <HEAD_SHA>
Mode:  <full | incremental | no-op | rebase-fallback>
Pages: <list of pages touched>
Secrets pass: <pass | findings: <count>>
Build:  <pass | <strict failures>>
Deploy: <workflow present | run /docs-deploy to scaffold>

### Findings (if any)
- [secrets] <page>: <what was redacted/blocked>
- [build]   <page>: <strict mkdocs error>
```

## Out of scope

- API reference extraction (a separate skill if ever needed; this
  skill writes design docs, not generated symbol references).
- Translation / multi-language sites.
- Non-mkdocs site generators (Sphinx, Hugo, mdBook). The output is
  intentionally just mkdocs — portable, but not generic.
- Pushing the docs branch / running `mkdocs gh-deploy --force`.
  Operator owns the push decision.
- Anything that requires the doc site to already exist on a host
  (custom-domain DNS, analytics injection).

## Self-improvement

If during execution you notice this skill has a clear bug (broken
script invocation, drifted template, wrong path) — fix it in the
authoritative copy at
`plugins/spindev-docs/skills/technical-writer/` in a clone of
`spinlockdevelopment/dev-setup`. The skill runs from a read-only
plugin cache, so edits there don't persist. Commit (bringup: straight
to `main`; protected: feature branch + PR), push. Consumers pick the
change up on their next `/plugin marketplace update`.

**Triggers for self-update:**

- mkdocs / mkdocs-material releases roll → bump the
  `tool_versions` notes in this SKILL.md and `templates/mkdocs.yml.tmpl`
  if a feature you depend on shifts.
- `actions/upload-pages-artifact` / `actions/deploy-pages` bump
  major versions → update `templates/deploy-mkdocs.yml.tmpl` and
  the dated `# pinned YYYY-MM-DD` comment inside it.
- pipx packaging recipe drift on Ubuntu → fix in `scripts/preflight.sh`.
