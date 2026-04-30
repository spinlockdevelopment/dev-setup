---
description: Scan the current repo and publish (or refresh) a mkdocs-formatted design doc — delta-aware on rerun, mkdocs-material theme, GitHub Pages-ready
---

Dispatch the `technical-writer` subagent against the current working tree. It will:

1. Run `scripts/run-all.sh` to preflight tooling, load any prior state, scan the repo, and decide between incremental and full regen.
2. Pick the doc-section menu adaptively from what the scan found, and write/update the relevant pages.
3. Run a secrets/PII pass before writing each page; block on findings rather than silently redact.
4. Validate with `mkdocs build --strict`, record the run in `~/.local/state/technical-writer/repos/<key>.json`.
5. Report a structured summary — pages touched, mode chosen, build result, suggested next steps.

The subagent does not push, commit, or open a PR — it reports so the operator can decide.

If the consumer repo already has a non-mkdocs `docs/` (Sphinx, mdBook, plain markdown), the skeleton goes in `design-docs/` instead and `mkdocs.yml` is configured with `docs_dir: design-docs`.

To force a full regen regardless of state, pass `--full-regen`. To run in read-only verify mode, pass `--verify`.

Arguments: $ARGUMENTS
