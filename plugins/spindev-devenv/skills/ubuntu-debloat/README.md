# ubuntu-debloat

Debloats a fresh Ubuntu desktop and sets it up for Claude Code + dev
work.

Purges games, office apps, Firefox, snapd (with an apt pin). Installs
Chrome (amd64) and Brave (amd64 + arm64) for browser coverage, plus
Docker CE, VS Code, Android Studio from upstream repos.
Manages Python, Node (LTS), Go, Java (LTS) via `mise`. Enables
`unattended-upgrades`. Scripts are idempotent, ship a `--verify`
read-only mode, and self-heal when pinned versions drift.

Ubuntu 24.04+ desktop only. Latest LTS / public-GA stable only.

Entry point: `./scripts/run-all.sh` (add `--verify` to check without
making changes). Individual numbered scripts can be run standalone.

## More

- Claude-facing decision tree, self-healing triggers, out-of-scope
  list: [`SKILL.md`](./SKILL.md)
- Install intent + symlink instructions: [root README](../../../README.md)
- Catalog entry: [`claude-skills.md`](../../../claude-skills.md)
