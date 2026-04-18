#!/usr/bin/env bash
# Detect bringup vs protected project mode.
# Prints "bringup" or "protected" to stdout. Always exits 0.
# Mirrors the heuristic in .claude/skills/end-session/SKILL.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

# No git repo → bringup.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo bringup
  exit 0
fi

# Signal 1 — any feature branches, local or remote. Exclude main/master,
# symbolic HEAD pointers, and bare remote refs (e.g. `origin` itself
# appears in `refs/remotes` output but is not a branch).
local_feature=$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null \
  | grep -Ev '^(main|master)$' | head -1 || true)
remote_feature=$(git for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null \
  | grep '/' \
  | grep -Ev '/(HEAD|main|master)$' | head -1 || true)
other_branches="${local_feature}${remote_feature}"

# Signal 2 — squash-merge / PR pattern in recent history. GitHub squash commits
# usually end with " (#NNN)"; many teams also use "Merge pull request #NNN".
pr_pattern=$(git log --oneline -50 2>/dev/null \
  | grep -E '(\(#[0-9]+\)$|Merge pull request #[0-9]+)' \
  | head -1 || true)

# Signal 3 — GitHub branch protection (only if gh is authenticated).
protection_signal=""
if have_gh_auth; then
  repo_slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  if [[ -n "$repo_slug" ]]; then
    if gh api "repos/$repo_slug/branches/main/protection" >/dev/null 2>&1; then
      protection_signal="yes"
    fi
  fi
fi

if [[ -n "$other_branches" || -n "$pr_pattern" || -n "$protection_signal" ]]; then
  echo protected
else
  echo bringup
fi
