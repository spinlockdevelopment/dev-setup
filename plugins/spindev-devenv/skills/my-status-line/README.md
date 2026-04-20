# my-status-line

A compact, opinionated Claude Code status line.

```
dev-setup | main | sandbox | ctx 127k (12%) | Opus 4.7
```

## What it shows

| Segment | Source | Omitted when |
|---|---|---|
| foldername | basename of `workspace.current_dir` | never |
| gitbranch | `git branch --show-current` | not in a git repo |
| sandbox | literal `sandbox` | `$HSHELL` is not `1` |
| ctx Nk (P%) | sum of last assistant turn's `input_tokens + cache_read_input_tokens + cache_creation_input_tokens` vs model max | never |
| Model | `model.display_name` with trailing `(1M context)` stripped | never |

Segments are joined with ` | `. Max context is `1,000,000` when the
model id ends in `[1m]`, otherwise `200,000`.

## Install

From a working clone of this marketplace, or from the plugin cache
after `/plugin install spindev-devenv@spinlockdevelopment`:

```bash
bash plugins/spindev-devenv/skills/my-status-line/scripts/install.sh
```

Or trigger the skill in-session:

```
/my-status-line
```

Both routes:

1. Copy `statusline.sh` to `~/.claude/statusline.sh` (chmod +x) and
   `statusline.py` to `~/.claude/statusline.py` (the `.sh` is a thin
   wrapper that executes the `.py` next to it).
2. Merge `statusLine: { type: "command", command: "bash <path>" }`
   into `~/.claude/settings.json`.

Restart Claude Code (or start a new session) to see the change.

## Verify

```bash
bash plugins/spindev-devenv/skills/my-status-line/scripts/install.sh --verify
```

Read-only; exits non-zero if the helper is missing, not executable, or
`statusLine` is not pointing at it.

## Uninstall

```bash
bash plugins/spindev-devenv/skills/my-status-line/scripts/uninstall.sh
```

Removes the helper script and unsets `statusLine` in
`~/.claude/settings.json`.

## Requirements

- Python 3 on `PATH` as `python3`, `python`, or `py`. Used by both
  scripts for JSON parsing. No `jq` dependency (intentional — `jq` is
  often missing on Windows Git Bash).
- `git` for the branch segment. If missing, the segment is simply
  omitted.

## Sandbox detection

Currently detects the `hardened-shell` sandbox (`hshell`) via its
`HSHELL=1` env var. Other sandboxes are not detected — contribute a
patch to `statusline.sh` if you want one added.

## Self-editing

This skill ships from a read-only plugin cache. To change its
behavior, edit the authoritative copy at
`plugins/spindev-devenv/skills/my-status-line/` in a clone of
`spinlockdevelopment/dev-setup`, commit, push. Re-run
`scripts/install.sh` after `/plugin marketplace update` to pick up the
new helper contents.
