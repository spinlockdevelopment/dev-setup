# hardened-shell

Ships `hshell`, a launcher that runs Claude (or other agents) in
`--dangerously-skip-permissions` mode inside a locked-down Docker
sandbox.

`$PWD` is bind-mounted as `/work` (the only writable world). The host
is mounted read-only at `/host` with a blocklist masking `~/.ssh`,
`~/.aws`, `~/.gnupg`, browser profiles, shell history, `/root`,
`/etc/shadow`, and other credential stores. Per-project Claude memory
persists at `$PWD/.internal/claude/`. Parallel agents coordinate via
git worktrees under `/work/.worktree/`.

Use when you want banshee mode's productivity without its blast
radius.

## More

- Full user guide (install, usage, credentials, troubleshooting,
  security notes, customization): [`USAGE.md`](./USAGE.md)
- Claude-facing decision tree + self-healing on LTS drift: [`SKILL.md`](./SKILL.md)
- Install intent + symlink instructions: [root README](../../../README.md)
- Catalog entry: [`claude-skills.md`](../../../claude-skills.md)
