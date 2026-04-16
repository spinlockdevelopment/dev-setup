# Session summaries

Append-only log of what each session accomplished. One entry per session,
newest at the bottom. Read the latest entry before resuming work in this
repo to avoid re-deriving context.

## 2026-04-16 — main

- Moved the `end-session` skill from `~/.claude/skills/end-session/` into
  this repo at `.claude/skills/end-session/` (SKILL.md + README.md) so it
  lives in git, then exposed it user-wide via a Windows directory
  junction (`mklink /J`).
- Discovered that Git Bash `ln -s` silently *copies* directories on this
  Windows host instead of linking — produced a duplicate skill listing
  before being caught. Cleaned up and used `mklink /J` (works without
  admin/developer mode). Documented the workaround in the install
  section of `claude-skills.md`.
- Added an `end-session` entry to `claude-skills.md` and a `## Project
  Mode` breadcrumb (bringup) plus a `SESSION-SUMMARIES.md` reference to
  `CLAUDE.md`.
- No tests / lint in this repo yet; quality gates skipped.

Future-you notes:
- The `ln -s` example in `claude-skills.md` is Linux/macOS only. On
  Windows, always use the `mklink /J` form documented right below it.
  Verify links with `cmd //c dir <parent>` — a real link shows
  `<JUNCTION>` (or `<SYMLINKD>`), not `<DIR>`.
- Bringup mode breadcrumb is in `CLAUDE.md`. Remove it the first time a
  feature branch + PR lands and switch wrap-up behavior to protected.
