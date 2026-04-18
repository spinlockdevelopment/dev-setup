# end-session

Wraps up a working session cleanly so a following `/clear` loses
nothing important.

Syncs project docs (`CLAUDE.md`, indexes, plans), prunes and updates
the persistent memory system, reconciles TodoWrite + project TODO
files, runs local quality gates (tests/typecheck/lint), appends to
`SESSION-SUMMARIES.md`, reconciles with `origin` to avoid
orphaned-commit confusion from squash merges, and — when feature
work is clearly complete — pushes a feature branch with PR +
auto-merge + squash. Worktree-aware. Always asks before destructive
git ops. Self-improves in place.

Detects **bringup** (commits to `main`) vs **protected** (feature
branch + PR) project mode and behaves accordingly.

Trigger with `/end-session` or phrases like "wrap up this session",
"prep for /clear", "we're done for now".

## More

- Claude-facing decision tree, 17-step flow, destructive-op policy:
  [`SKILL.md`](./SKILL.md)
- Install intent + symlink instructions: [root README](../../../README.md)
- Catalog entry: [`claude-skills.md`](../../../claude-skills.md)
