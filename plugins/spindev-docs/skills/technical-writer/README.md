# technical-writer — repo-aware design doc generator

Human-facing overview.

## What it is

A skill (and a Claude subagent that wraps it) that scans an entire
repository and publishes a coherent, mkdocs-formatted design doc. It
is **delta-aware**: on rerun, it consults a per-repo state file (the
last commit it documented) and either incrementally updates only the
pages whose source files changed, or full-regenerates if the delta is
too disruptive to merge cleanly.

Output is plain [mkdocs](https://www.mkdocs.org/) with the
[mkdocs-material](https://squidfunk.github.io/mkdocs-material/) theme
— ready to deploy to GitHub Pages via the included workflow template,
or to any static host that consumes mkdocs `site/` output (Cloudflare
Pages, Netlify, S3 + CloudFront, plain `python -m http.server`).

## Why it exists

A design doc that lives only in the head of whoever last touched the
repo isn't a design doc. Auto-generated API references from docstrings
aren't a design doc either — they tell you what the symbols are, not
how the system fits together or why it exists.

This skill produces the second kind of doc: an opinionated narrative
walkthrough — landing page, architecture, components, data flow,
deployment, operations, glossary — adaptive to what the repo actually
contains. The writer skips sections whose source surface is empty
rather than ship empty stubs.

## Why these choices

- **mkdocs over Sphinx / mdBook / Hugo** — mkdocs is the lowest-effort
  path from "directory of Markdown" to "deployable static site". Theme
  maturity (mkdocs-material), Python-native install, single-file
  config.
- **mkdocs-material** — the de facto theme. Search, code highlighting,
  navigation, and dark mode all out-of-the-box.
- **Delta-aware** — full regen on every run is wasteful and noisy in
  git. Incremental updates keep diffs small and reviewable. The
  writer (LLM, not a hardcoded threshold) decides when the delta is
  too large for incremental and falls back to full regen.
- **State outside the repo** (`~/.local/state/technical-writer/`) —
  per-repo last-commit pointer, not committed; survives skill
  updates; doesn't pollute `.gitignore`.
- **`design-docs/` fallback** — many repos already have `docs/` for
  plain Markdown or Sphinx. We refuse to overwrite by default; the
  skeleton goes in `design-docs/` and `mkdocs.yml` is configured
  with `docs_dir: design-docs`.
- **GitHub Pages workflow opt-in via `/docs-deploy`** — generation and
  publication are separate decisions. Run the writer on every PR;
  publish only when ready.
- **Pre-publish secrets/PII pass** — the writer can paraphrase a
  secret out of a code comment in a way `gitleaks` won't catch on
  the source file. A second eye before write blocks that path.

## What it does

- Probes for `mkdocs` + `pipx` (skips install if present; `pipx
  install mkdocs mkdocs-material mkdocs-awesome-pages-plugin` if
  missing and pipx is available).
- Reads any prior state for this repo from
  `~/.local/state/technical-writer/repos/<repo-key>.json`.
- Inventories the repo: top-level layout, language census, manifests,
  entrypoints, deploy artifacts, README/CONTRIBUTING/CHANGELOG.
- Decides incremental vs full vs no-op based on git diff.
- Materializes / updates pages from the templates, dropping any
  section whose source surface is empty.
- Runs a Haiku-scale secrets/PII pass on each page before write.
- Validates with `mkdocs build --strict`.
- Records the new state.
- Optionally (separate command) scaffolds a `.github/workflows/deploy-mkdocs.yml`
  for GitHub Pages deployment.

## Installation intent

User-level via the plugin marketplace. Auto-loads when
`spindev-docs` is enabled.

```bash
# Claude Code
/plugin marketplace add spinlockdevelopment/dev-setup
/plugin install spindev-docs

# Codex CLI
codex plugin marketplace add /path/to/dev-setup
# then enable spindev-docs in your Codex config

# Gemini CLI
gemini extensions install /path/to/dev-setup/plugins/spindev-docs
```

`mkdocs` and `mkdocs-material` install via `pipx` on first run if
they are missing — see `USAGE.md` for the deep how-to.

## Entry points

- `SKILL.md` — Claude / Codex / Gemini decision tree.
- `agents/technical-writer.md` (Claude only) — subagent prompt.
- `commands/technical-writer.md` / `.toml` — `/technical-writer`
  slash command (Claude / Gemini).
- `commands/docs-deploy.md` / `.toml` — `/docs-deploy` slash command.
- `scripts/run-all.sh` — orchestrator (also `--verify`, `--full-regen`).
- `scripts/preflight.sh` — tooling check / pipx install.
- `scripts/state.sh` — read/write/clear/delta of the per-repo state.
- `scripts/scan-repo.sh` — emit JSON inventory.
- `scripts/scaffold-mkdocs.sh` — first-time scaffold.
- `scripts/build-docs.sh` — `mkdocs build` (and `--strict` in verify).
- `scripts/deploy-gh-pages.sh` — drop the GH Actions workflow.

See `USAGE.md` for the user-facing CLI deep-dive.

## Pairing

- [`init-project`](../../../spindev-core/skills/init-project/) — run
  `/init-project` first to establish the repo baseline, then
  `/technical-writer` to produce the design doc.
- [`end-session`](../../../spindev-core/skills/end-session/) — when
  wrapping up a session that touched architecture, run
  `/technical-writer` so the next session opens on a fresh design
  doc rather than re-deriving the system.
- Any directory — works on any git repo with at least one commit.
