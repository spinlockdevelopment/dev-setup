---
description: Scaffold a GitHub Pages deployment workflow for the mkdocs site (modern actions/upload-pages-artifact + actions/deploy-pages flow; no gh-pages branch)
---

Run `scripts/deploy-gh-pages.sh` from the `technical-writer` skill against the current repo. It will:

1. Drop `.github/workflows/deploy-mkdocs.yml` (idempotent — never overwrites an existing workflow).
2. Print the next steps: commit + push the workflow, then enable Pages in repo settings (Source: GitHub Actions).

The workflow triggers on push to `main` whenever `docs/`, `design-docs/`, `mkdocs.yml`, or itself changes. It builds with `mkdocs build` and deploys via `actions/upload-pages-artifact@v3` + `actions/deploy-pages@v4`.

For non-Pages targets (Cloudflare Pages, Netlify, plain artifact), the `mkdocs build` output in `site/` is the artifact — no workflow scaffold needed; configure your host to run `mkdocs build` and serve `site/`.

This command does not push. The operator owns the push decision.

Arguments: $ARGUMENTS
