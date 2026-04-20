---
description: Install the spindev-devenv compact status line (foldername | branch | sandbox | ctx | model).
---

Use the `my-status-line` skill to install the compact Claude Code status line.

The skill's install script:

1. Copies `statusline.sh` to `~/.claude/statusline.sh`.
2. Wires `statusLine` in `~/.claude/settings.json` to run it.

The resulting status line looks like:

```
dev-setup | main | sandbox | ctx 127k (12%) | Opus 4.7
```

If the user asks to verify or uninstall instead, call the same skill —
its decision tree covers `scripts/install.sh --verify` and
`scripts/uninstall.sh`.
