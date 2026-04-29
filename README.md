# spindev — Multi-agent plugin collection

Personal plugin marketplace and extension collection for **Codex CLI**, **Claude Code**, and **Gemini CLI**. Ships three plugins grouping skills, command wrappers, hooks, and companion scripts for project lifecycle, developer-environment setup, and deployment-target references.

## Installation

### Codex CLI (Marketplace)
This checkout is a Codex marketplace rooted at
[`.agents/plugins/marketplace.json`](./.agents/plugins/marketplace.json).
Add it from a consuming project or from this checkout:

```bash
codex plugin marketplace add /path/to/dev-setup
```

The marketplace publishes three local plugins:

```text
./plugins/spindev-core
./plugins/spindev-devenv
./plugins/spindev-deploy
```

Each plugin has a Codex manifest at
`plugins/<plugin>/.codex-plugin/plugin.json` and points Codex at the
shared `skills/` directory.

### Gemini CLI (Extensions)
Install the plugins as Gemini CLI extensions directly from the local checkout:

```bash
gemini extensions install ./plugins/spindev-core
gemini extensions install ./plugins/spindev-devenv
gemini extensions install ./plugins/spindev-deploy
```

### Claude Code (Marketplace)
Add the marketplace and turn on the plugins you want in your project's `.claude/settings.json`:

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

## Plugin catalog

### `spindev-core`
Session / project-lifecycle primitives — enable on every project.
- `end-session` — syncs docs/memory, runs quality gates, creates PR with auto-merge
- `gh` — playbook for GitHub org/repo provisioning and PAT setup
- `init-project` — brings a repo up to baseline conventions
- `pr-prepass` (subagent) — local mirror of the PR auto-review CI
- `review-plan` — pre-implementation hardening for plans

Slash commands: `/end-session`, `/init-project`, `/pr-prepass`, `/review-plan`.

### `spindev-devenv`
Developer-machine setup + sandboxed agent execution.
- `create-gh-token` — mint and wire a project-specific GitHub PAT
- `hardened-shell` — the `hshell` Docker sandbox launcher
- `my-status-line` — compact status line for the terminal
- `ubuntu-debloat` — idempotent fresh-Ubuntu setup

Slash commands: `/create-gh-token`.

### `spindev-deploy`
Deployment-target reference skills.
- `flyio` — playbook for fly.io deployments
- `sprites-dev` — correct-usage rules for sprites.dev

## Project Structure
Skills and subagents are shared between Codex, Claude, and Gemini. Each
plugin contains agent-specific manifests (`.codex-plugin/plugin.json`,
`.claude-plugin/plugin.json`, `gemini-extension.json`) and command
wrappers where the target agent supports them (`.md`, `.toml`).

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

Validate Claude manifests before pushing:

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

This flow applies to agent self-improvement too: skills in this repo may
tell Codex, Claude, or Gemini to "self-heal" or "update in place" when
they spot drift. Those edits belong here, not in an installed cache.

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
8. If plugin-level metadata changed, update the matching Codex
   manifest in `plugins/<plugin>/.codex-plugin/plugin.json`.

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
