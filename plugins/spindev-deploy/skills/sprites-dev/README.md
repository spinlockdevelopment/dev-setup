# sprites-dev

Correct-usage reference for the `sprite` CLI and the sprites.dev API on
Windows / Git Bash. Prevents the path-mangling, flag-ordering, and
large-file-upload failures that otherwise happen silently.

Trigger automatically on any mention of Fly.io Sprites, `sprite exec`,
`sprite api`, `sprite console`, or uploading files into a sprite.

## More

- Claude-facing rules + quick reference: [`SKILL.md`](./SKILL.md)
- Install intent + symlink instructions: [root README](../../../README.md)
- Catalog entry: [`claude-skills.md`](../../../claude-skills.md)

## Installation intent

**Project-level** (for now) — tied to how the RadioCalls-Dashboard
project deploys to sprites.dev. Map from this canonical location into
any project that hits sprites via a Windows directory junction:

```bash
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 cmd.exe /c mklink /J \
  'C:\Users\<you>\src\<project>\.claude\skills\sprites-dev' \
  'C:\Users\<you>\src\dev-setup\.claude\skills\sprites-dev'
```

Promote to user-level later (symlink into `~/.claude/skills/sprites-dev/`)
if sprites end up being used from more than one project.
