# Migration Plan

Grouping proposal for refactoring `dev-setup` into a Claude Code plugin
marketplace. Produced per Step 2 of the porting guide and approved by the
maintainer before the move.

## Plugin grouping

| Plugin | Skills (count) | Commands | Rationale |
|---|---|---|---|
| `spindev-core` | 3: `end-session`, `init-project`, `review-plan` | `/end-session`, `/init-project`, `/review-plan` | Session / project-lifecycle primitives. Used in >80% of projects. All three existing slash-command wrappers bind to these skills, so they ship together. |
| `spindev-devenv` | 2: `hardened-shell`, `ubuntu-debloat` | — | Developer-machine setup + sandbox execution. Both are environment-level (not per-project), ship real CLIs / Docker images, and have heavy `scripts/` trees. Projects that don't need them skip the whole plugin. |
| `spindev-deploy` | 1: `sprites-dev` | — | Deployment-platform-specific skills. Starts as home for `sprites-dev`; future deploy-target skills (other PaaS, publish pipelines) land here so they don't bloat `spindev-core`. |

## Why three plugins instead of one

The porting guide's heuristics:

- Plugins should be independently useful — a project enabling only one plugin
  should get a coherent experience.
- Skills used in >80% of projects belong in `spindev-core`.
- Prefer fewer, larger plugins over many small ones. Split only when
  projects have clearly different needs.

The split above follows these rules:

- `spindev-core` is the "every project wants this" bundle — session
  management and project bringup apply everywhere.
- `spindev-devenv` is only useful on developer boxes / sandboxed runs. A
  Claude Code Web project deploying to Sprites has no use for it, so it
  stays opt-in.
- `spindev-deploy` is only useful when a project actually deploys to that
  platform. Folding `sprites-dev` into `spindev-core` would drag a narrow
  Windows/Git Bash gotcha-reference into every project.

## Why not 2 or 4 plugins

- **2 plugins (fold `sprites-dev` into `spindev-core`)** — pollutes the
  always-on bundle with a skill that's only relevant for one deploy target
  and one OS.
- **4 plugins (split `spindev-devenv` into `spindev-sandbox` +
  `spindev-os-setup`)** — each would have exactly one skill, which
  contradicts the guide's "prefer fewer, larger plugins" rule. Both
  skills are environment-setup and ship heavy script trees, so a single
  `spindev-devenv` coheres fine.

## Versioning

All three plugins start at `0.1.0` per the guide. Version bumps happen
later as individual skills evolve.

## Owner / author

- Marketplace owner: Chris (github.com/spinlockdevelopment)
- Plugin author: same

## Execution order

Matches the guide's Step-9 commit order:

1. `chore: add migration inventory and plan`
2. `refactor: scaffold multi-plugin marketplace directory structure`
3. `refactor: move skills into plugin folders`
4. `feat: add plugin.json manifests`
5. `feat: add marketplace.json registry`
6. `docs: rewrite README for marketplace consumers`

Commits land directly on `main` per maintainer's explicit instruction.
