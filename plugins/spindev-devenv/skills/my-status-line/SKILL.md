---
name: my-status-line
description: Install a compact Claude Code status line — `foldername | gitbranch | sandbox | ctx Nk (P%) | Model`. Runs an idempotent install script that drops a statusline helper at `~/.claude/statusline.sh` and wires it into `~/.claude/settings.json`. Use when the user asks to install this repo's status line, says "my status line", runs `/my-status-line`, or asks to customize their Claude Code status bar to show token-context usage and sandbox state.
---

# my-status-line

Thin skill. Real work is in `scripts/`. You orchestrate: install, verify,
or uninstall.

## What the user gets

A status line like:

```
dev-setup | main | sandbox | ctx 127k (12%) | Opus 4.7
```

Segments (left to right):

1. **foldername** — basename of the current working directory.
2. **gitbranch** — current git branch. Segment omitted when not in a repo.
3. **sandbox** — literal word `sandbox` when `$HSHELL=1` (the
   `hardened-shell` sandbox). Segment omitted otherwise.
4. **ctx Nk (P%)** — tokens used in the current context window (input +
   cache-read + cache-creation from the last assistant turn) and that as
   a percentage of the model's max. Max is `1,000,000` for 1M-context
   models (model id ends in `[1m]`), else `200,000`.
5. **Model** — `model.display_name` with any trailing `(1M context)` /
   `[1M context]` suffix stripped.

Segments are joined with ` | `.

## Decision tree for Claude

1. **"install my status line" / fresh setup / `/my-status-line`** →
   `scripts/install.sh`. Idempotent; safe to re-run to pick up script
   updates.
2. **"check my status line" / "verify"** → `scripts/install.sh --verify`.
3. **"remove my status line" / "uninstall"** → `scripts/uninstall.sh`.

Install copies both `statusline.sh` and `statusline.py` to
`~/.claude/` (stable paths, survive plugin-cache version bumps) and
sets `statusLine` in `~/.claude/settings.json` to run
`bash ~/.claude/statusline.sh`. The `.sh` is a thin wrapper that
execs the `.py` next to it; keeping them as separate files avoids
the `python - <<HEREDOC` stdin-consumption trap (Claude Code pipes
the statusLine JSON payload on stdin, which the heredoc would eat).

## Prerequisites

- `python3` (or `python` / `py`) on `PATH`. Used for JSON parsing by
  both scripts. Portable across Linux/macOS/Windows Git Bash without
  needing `jq`.
- `git` on `PATH` (only needed for the branch segment; missing git just
  drops the segment).

## Self-healing

This skill is served from a read-only plugin cache
(`~/.claude/plugins/cache/spindev-devenv@spinlockdevelopment/<version>/`).
Edits there do not persist. Edit the authoritative copy at
`plugins/spindev-devenv/skills/my-status-line/` in a clone of
`spinlockdevelopment/dev-setup`, commit (bringup: straight to `main`;
protected: feature branch + PR), push. Users re-run `scripts/install.sh`
after `/plugin marketplace update` to pick up the new script content.

**Triggers for self-update:**

- Claude Code changes the statusLine stdin JSON shape (field renames,
  new fields) → fix `statusline.sh` parsing.
- A new 1M-context model id uses a different suffix than `[1m]` →
  extend the `max` detection in `statusline.sh`.
- Sandbox detection grows beyond `$HSHELL=1` (e.g., Claude Code Web
  sets a detectable env var) → add the new check.

## Files

| File | Purpose |
|---|---|
| `scripts/statusline.sh` | Thin bash wrapper. Locates `python3`/`python`/`py` and execs `statusline.py` next to it. |
| `scripts/statusline.py` | The actual helper. Reads JSON on stdin, emits one status-line string. |
| `scripts/install.sh` | Copies `statusline.sh` + `statusline.py` to `~/.claude/` and wires `statusLine` into `~/.claude/settings.json`. `--verify` for read-only check. |
| `scripts/uninstall.sh` | Removes the helper files and unsets `statusLine` in `~/.claude/settings.json`. |
