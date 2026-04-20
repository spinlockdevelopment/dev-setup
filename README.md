# spinlockdevelopment — Claude Code plugin marketplace

Personal Claude Code plugin marketplace. Ships three plugins grouping
skills + slash commands for project lifecycle, developer-environment
setup, and deployment-target references.

Skills were previously consumed from this repo by symlinking individual
directories into `~/.claude/skills/`. That model broke on Claude Code
Web (sandboxes start fresh, can't see user-level symlinks), so the repo
was refactored into a marketplace. Each project now opts in by listing
this marketplace and the plugins it wants in its own
`.claude/settings.json`.

## What's in here

| Path | Purpose |
|---|---|
| [`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json) | Marketplace registry — lists all plugins and how to find them. |
| [`plugins/spindev-core/`](./plugins/spindev-core/) | Session / project-lifecycle primitives. Slash commands: `/end-session`, `/init-project`, `/review-plan`. |
| [`plugins/spindev-devenv/`](./plugins/spindev-devenv/) | Developer-machine setup (`ubuntu-debloat`), sandbox execution (`hardened-shell` + `hshell` CLI), and per-project GitHub PAT wiring (`create-gh-token`). |
| [`plugins/spindev-deploy/`](./plugins/spindev-deploy/) | Deployment-target reference skills (currently `sprites-dev`). |
| [`claude-skills.md`](./claude-skills.md) | Authoritative index of every skill across all plugins. |
| [`CLAUDE.md`](./CLAUDE.md) | Claude-facing guidance for working inside this repo. |
| [`SESSION-SUMMARIES.md`](./SESSION-SUMMARIES.md) | Append-only log of session outcomes. |

## Plugin catalog

### `spindev-core`

Session / project-lifecycle primitives — enable on every project.

- `end-session` — wraps up a session before `/clear`: syncs docs/memory/TODOs, runs quality gates, opens a PR with auto-merge when work is complete
- `init-project` — brings a repo up to baseline: git + main, bringup/protected breadcrumb, minimal `CLAUDE.md`/`README.md`, canonical PR-workflow rules block
- `review-plan` — pre-implementation hardening for superpowers plans: cross-model adversarial review + checkpoint-block injection

Slash commands: `/end-session`, `/init-project`, `/review-plan`.

### `spindev-devenv`

Developer-machine setup + sandboxed agent execution. Enable on boxes
where you actually bring up dev environments or run banshee-mode
agents. Skip on Claude Code Web sandboxes.

- `create-gh-token` — mint a fine-grained GitHub PAT tailored to one project (4 short questions → concise PAT-creation checklist → script that validates the pasted token and rewrites the project's HTTPS git remote so pushes work without prompting). Token lives only in `.git/config`.
- `hardened-shell` — the `hshell` Docker sandbox launcher (banshee-mode Claude runs in a read-only-host / writable-pwd jail with credential masking). Build the image + install the launcher per the skill's [`USAGE.md`](./plugins/spindev-devenv/skills/hardened-shell/USAGE.md).
- `my-status-line` — installs a compact Claude Code status line (`foldername | branch | sandbox | ctx Nk (P%) | Model`) into `~/.claude/settings.json`. Slash command: `/my-status-line`.
- `ubuntu-debloat` — idempotent fresh-Ubuntu setup: purge games/office/Firefox/snapd, install Chrome, Brave, Docker CE, mise-managed Python/Node/Go/JDK, Android Studio, VS Code. Linux only.

Slash commands: `/create-gh-token`.

### `spindev-deploy`

Deployment-target reference skills — enable on projects that deploy to
the matching platform.

- `sprites-dev` — correct-usage rules for the `sprite` CLI and sprites.dev API on Windows / Git Bash. Avoids path mangling, flag-ordering bugs, and large-file upload failures. Every rule traces to a real failure.

## Install in your project

Add the marketplace and turn on the plugins you want in your
project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "spinlockdevelopment": {
      "source": {
        "source": "github",
        "repo": "spinlockdevelopment/dev-setup"
      }
    }
  },
  "enabledPlugins": {
    "spindev-core@spinlockdevelopment": true,
    "spindev-devenv@spinlockdevelopment": true,
    "spindev-deploy@spinlockdevelopment": true
  }
}
```

Keep only the plugins the project actually needs. Most projects want
`spindev-core`; add `spindev-devenv` on developer boxes and
`spindev-deploy` on projects that deploy to one of its target
platforms.

The first time Claude Code starts in a project that trusts this
settings file, it prompts to add the marketplace. You can also add it
manually:

```shell
/plugin marketplace add spinlockdevelopment/dev-setup
/plugin install spindev-core@spinlockdevelopment
```

Private-repository note: to get background auto-updates without
credential prompts, export a `GITHUB_TOKEN` with repo-read scope. See
[the Claude Code docs](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces#private-repositories).

## Extra install steps beyond the marketplace

Most skills are pure Markdown + scripts and load as soon as the plugin
is enabled. Two need extra host setup:

- **`hardened-shell`** — also build the Docker image and install the
  `hshell` launcher. See [`USAGE.md`](./plugins/spindev-devenv/skills/hardened-shell/USAGE.md#installation).
- **`ubuntu-debloat`** — runs on Ubuntu only. The skill itself needs
  nothing extra installed; invoking it runs the numbered scripts in
  `plugins/spindev-devenv/skills/ubuntu-debloat/scripts/`.

## Developing against this repo

Skills and commands auto-load when Claude Code runs inside this repo
(they're discovered from `plugins/*/skills/` and `plugins/*/commands/`
directly). To test the marketplace wiring end-to-end:

```shell
/plugin marketplace add /path/to/dev-setup
/plugin install spindev-core@spinlockdevelopment
```

Validate manifests before pushing:

```shell
claude plugin validate .
```

Or inside a session:

```shell
/plugin validate .
```

## Updating a skill (contributing back)

Plugins are copied into a **read-only cache** at
`~/.claude/plugins/cache/<plugin>@<marketplace>/<version>/` when they
install, so edits inside that cache do not persist and do not flow
back here. To actually update a skill:

1. Clone this repo (e.g. `git clone https://github.com/spinlockdevelopment/dev-setup ~/src/dev-setup`) or open an existing checkout.
2. Edit `plugins/<plugin>/skills/<skill>/SKILL.md` (or its scripts / assets) in the clone.
3. Commit. In bringup mode that's a direct commit to `main`; in protected mode, push a feature branch + PR.
4. Push. Consumer projects pick up the change on their next `/plugin marketplace update`.

This flow applies to Claude too: skills in this repo tell Claude to
"self-heal" or "update in place" when they spot drift. Those edits
belong here, not in the cache.

## Conventions for skills in this repo

- **Thin `SKILL.md`.** It's Claude's decision tree, not an instruction
  manual — the body tells Claude *when* to do what; scripts know *how*.
- **`README.md` per skill.** Human-facing plain-English overview.
- **Tight frontmatter descriptions.** Descriptions load into context;
  keep them short but specific enough to trigger reliably.
- **Heavy lifting in `scripts/`.** Idempotent bash, numerically ordered
  when there's a phase sequence, `--verify` mode where applicable.
- **Self-healing.** Skills that pin upstream versions (URLs, LTS
  releases, package names) include instructions for Claude to detect
  drift and update pinned values in place.
- **LTS / GA stable only.** Skills target the latest LTS or public-GA
  release, not bleeding-edge.

## Adding a new skill

1. Pick the right plugin (`spindev-core` for lifecycle,
   `spindev-devenv` for box/sandbox setup, `spindev-deploy` for
   deploy-target references).
2. Create
   `plugins/<plugin>/skills/<name>/SKILL.md` with YAML frontmatter
   (`name`, `description`) and a thin body.
3. Create `plugins/<plugin>/skills/<name>/README.md` — plain-English
   overview.
4. Put scripts in `plugins/<plugin>/skills/<name>/scripts/` (numbered if
   there's a phase sequence; include a shared `lib.sh` if
   script-heavy — see `ubuntu-debloat`).
5. If the skill is user-facing (has a CLI the user drives directly),
   add `USAGE.md` alongside `README.md` — see `hardened-shell/`.
6. Add an entry to [`claude-skills.md`](./claude-skills.md) under the
   right plugin section.
7. Update the plugin catalog in this README.

## Adding a new slash command

Drop `plugins/<plugin>/commands/<name>.md` — thin prompt file with
`description` frontmatter, delegating to the same-named skill. Commands
ship with the same plugin as the skill they wrap.

## Project mode

**Bringup.** Commits go straight to `main`, no feature branches, no PR
workflow yet. Promote to protected mode (and remove the breadcrumb in
`CLAUDE.md`) when the first feature branch + PR lands.

## Session history

See [`SESSION-SUMMARIES.md`](./SESSION-SUMMARIES.md) for dated entries
of what each session accomplished. Read the latest entry before
resuming work to avoid re-deriving context.
