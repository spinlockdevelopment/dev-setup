# technical-writer — User Guide

This is the **user-facing guide**. For the agent-facing decision tree
and self-healing rules, see [SKILL.md](./SKILL.md). For a plain-English
overview of what the skill is and why, see [README.md](./README.md).

## Installation

The skill itself loads automatically when `spindev-docs` is enabled in
your harness's marketplace. The Python tooling (`mkdocs`,
`mkdocs-material`) is installed on first run via `pipx`.

```bash
# Verify tooling without installing or running anything:
./scripts/preflight.sh --verify

# Install mkdocs + mkdocs-material via pipx if missing (idempotent):
./scripts/preflight.sh
```

If `pipx` itself is missing, `preflight.sh` prints the apt install
command for you to run with the bang-prefix and exits. We don't sudo
from inside the agent; you authorize the package install.

```bash
! sudo apt install -y pipx && pipx ensurepath
```

After `pipx ensurepath`, open a new shell so `~/.local/bin` is on
`PATH`, then re-run preflight.

## Usage

```bash
# Full or incremental run (auto-decides based on state + git diff):
./scripts/run-all.sh

# Force a full regen regardless of state:
./scripts/run-all.sh --full-regen

# Read-only check: tooling, state, commits behind HEAD, current pages.
# Writes nothing.
./scripts/run-all.sh --verify

# Just the build, against an existing docs/ tree:
./scripts/build-docs.sh
./scripts/build-docs.sh --verify   # mkdocs build --strict

# Scaffold the GitHub Pages workflow into the consumer repo:
./scripts/deploy-gh-pages.sh
```

The slash commands invoke the same scripts:

- `/technical-writer` (Claude / Gemini) — runs `run-all.sh` via the
  subagent (Claude) or the skill body (Gemini / Codex).
- `/docs-deploy` (Claude / Gemini) — runs `deploy-gh-pages.sh`.

### The first run per repo

The first time you run the writer in a given repo, it:

1. Probes git, mkdocs, pipx via `preflight.sh`.
2. Inventories the repo via `scan-repo.sh` (JSON to stdout).
3. Decides where the docs root goes:
   - If `docs/` doesn't exist or already contains a mkdocs `index.md`,
     uses `docs/`.
   - If `docs/` exists with anything else (Sphinx, mdBook, plain
     Markdown), the skeleton goes in `design-docs/` instead and
     `mkdocs.yml` is configured with `docs_dir: design-docs`.
4. Materializes `mkdocs.yml` (if missing) and the relevant subset of
   page templates from `templates/`.
5. Lets the agent (Claude / Codex / Gemini) write the prose for each
   page, drawing on the scan output.
6. Runs a secrets/PII pass on each page before write.
7. Validates with `mkdocs build --strict`.
8. Records the run in
   `~/.local/state/technical-writer/repos/<repo-key>.json`.

### Subsequent runs

The orchestrator reads the state file, asks git for the diff since
the last documented commit, and decides:

- **No diff** → no-op; refreshes only `last_run_iso`.
- **Linear diff (state's last commit is an ancestor of HEAD)** →
  incremental update. The agent decides per-page whether to edit in
  place or regenerate.
- **Non-linear diff** (rebase, force-push, branch swap) → full regen
  with the reason logged.

Force a full regen with `--full-regen`.

## State and where it lives

```
~/.local/state/technical-writer/
├── index.json                   # repo-key → human path map
└── repos/
    └── <repo-key>.json          # per-repo state
```

`<repo-key>` = `sha256(remote.origin.url || git rev-parse --show-toplevel)[:16]`.

State JSON shape:

```json
{
  "schema": 1,
  "repo_key": "...",
  "remote_url": "git@github.com:org/repo.git",
  "worktree": "/abs/path",
  "last_commit": "<sha>",
  "last_branch": "main",
  "last_run_iso": "2026-04-29T12:34:56Z",
  "doc_root": "docs",
  "mkdocs_config": "mkdocs.yml",
  "pages_generated": ["index.md", "architecture.md", "components.md"],
  "tool_versions": { "mkdocs": "1.6.1", "material": "9.5.x" }
}
```

Inspect or list:

```bash
./scripts/state.sh read              # current repo
./scripts/state.sh list-repos        # everything you've documented
./scripts/state.sh delta             # changed files since last run
./scripts/state.sh clear             # forget this repo
```

## Output layout

| Path in your repo | When |
|---|---|
| `mkdocs.yml` | Always (root). Material theme. |
| `docs/` | First run, when `docs/` is unused. |
| `design-docs/` | First run, when `docs/` is already populated. |
| `site/` | After `mkdocs build`. **Add to `.gitignore`** (the scaffold script does this if missing). |
| `.github/workflows/deploy-mkdocs.yml` | Only when `/docs-deploy` is run. |

## Local preview

```bash
mkdocs serve                  # http://127.0.0.1:8000
mkdocs serve -a 0.0.0.0:8000  # for LAN preview from another box
```

`mkdocs serve` watches `docs/` (or `design-docs/`) and `mkdocs.yml`
and auto-rebuilds on changes. It does NOT re-run the agent — it just
re-renders the existing Markdown.

## Deploying

### GitHub Pages (recommended)

```bash
./scripts/deploy-gh-pages.sh   # or: /docs-deploy
```

This drops `.github/workflows/deploy-mkdocs.yml` into your repo. The
workflow:

- Triggers on push to `main` when `docs/`, `design-docs/`, `mkdocs.yml`,
  or itself changes.
- Builds with `mkdocs build`.
- Uploads via `actions/upload-pages-artifact@v3`.
- Deploys via `actions/deploy-pages@v4` (no `gh-pages` branch).

After the first push you must enable Pages in your repo settings:

> Settings → Pages → Source → **GitHub Actions**

The script prints these instructions on completion.

### Cloudflare Pages

Point a Cloudflare Pages project at your repo. Build command:
`mkdocs build`. Build output directory: `site`. Done — no workflow
file needed.

### Netlify

Same idea. Build command: `mkdocs build`. Publish directory: `site`.

### Plain artifact

Run `./scripts/build-docs.sh`, then upload `site/` to whatever you
have (S3, nginx, `python -m http.server` for local sharing, etc.).

## Troubleshooting

### `mkdocs: command not found`
Run `./scripts/preflight.sh`. If pipx isn't installed, the script
prints the `! sudo apt install -y pipx && pipx ensurepath` line for
you to run.

### `state file is for a different worktree`
You ran the skill from a worktree with a different
`git rev-parse --show-toplevel` than the one in state. Either run
from the original worktree, or `./scripts/state.sh clear` and start
fresh in the new one.

### `merge-base --is-ancestor` returned non-zero
Your branch was rebased / force-pushed since the last documented
commit. The orchestrator falls back to a full regen automatically and
logs the reason. Nothing for you to fix.

### `mkdocs build --strict` reports broken nav links
A page referenced in `mkdocs.yml`'s `nav:` doesn't exist on disk, or
a Markdown link points at a stale path. Fix the source page; rerun.
The validation step is intentionally strict so broken sites don't
get published.

### Secrets/PII pass blocked a write
Open the offending page and look for the flagged content. The pass
is conservative — false positives happen on `.env.example` files
that genuinely use placeholder values. To force-write the page
anyway, edit it manually and rerun (the pass runs only on
agent-generated changes).

### "I don't want a section the writer chose"
Edit the page (or delete it), then update `mkdocs.yml`'s `nav:` to
remove the entry. Rerun with `--full-regen` if you want the writer
to permanently drop that section.

### "I want a section the writer didn't generate"
Add an empty Markdown file at `docs/<section>.md` (or
`design-docs/<section>.md`) and add it to `nav:`. The writer will
fill it on the next run.

## Customization

### Theme tweaks

Edit `mkdocs.yml` after the first scaffold. The writer never
re-touches `mkdocs.yml`'s `theme:` block on incremental runs — it
only updates `nav:` and `site_name`. To regenerate the whole config
from the template, `rm mkdocs.yml && ./scripts/run-all.sh
--full-regen`.

### A different docs directory

Pass `DOCS_DIR=...` before invoking `run-all.sh`:

```bash
DOCS_DIR=site-docs ./scripts/run-all.sh
```

The scaffold script honors that env var on first run; on subsequent
runs the value is read from state.

### Forget a repo entirely

```bash
./scripts/state.sh clear
```

Removes the per-repo state file. Next run starts fresh (full
generation).

## Uninstall

```bash
# Remove the GH Actions workflow (if scaffolded)
rm .github/workflows/deploy-mkdocs.yml

# Remove docs (and/or design-docs) from your repo
rm -rf docs design-docs mkdocs.yml site

# Forget this repo's state
./scripts/state.sh clear

# Optional: remove the Python tooling
pipx uninstall mkdocs
```
