#!/usr/bin/env bash
# gh-workflow — non-blocking PreToolUse advisory hook for spindev-core.
#
# Surfaces stderr advisories when the operator (or Claude) is about to
# run a `gh` or `git push` command that drifts from the project's
# preferred PR workflow:
#
#   - `gh repo create` without --template/--source/--clone
#   - `gh pr merge` without an explicit merge strategy (--squash is
#     the project standard)
#   - `git push` to main/master/staging/prod (always advise — protected
#     mode strongly disfavors it; bringup mode it's fine but worth a
#     visible nudge)
#   - `git push --force` (or --force-with-lease) at a protected branch
#
# This is a TWO-WEEK-REVIEW hook (introduced 2026-04-29). If the
# advisories prove to be noise rather than signal, remove the hook
# entry from plugins/spindev-core/hooks/hooks.json. The skill file at
# plugins/spindev-core/skills/gh/SKILL.md notes the review window so
# the decision is recoverable.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Bash" ] || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

ACTUAL=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+//')

WARNINGS=()

# gh repo create without a template/source flag.
if printf '%s' "$ACTUAL" | grep -qE '^gh[[:space:]]+repo[[:space:]]+create\b' \
   && ! printf '%s' "$ACTUAL" | grep -qE '([[:space:]]|^)(--template|--source|--clone)([=[:space:]]|$)'; then
  WARNINGS+=("gh repo create without --template/--source/--clone — fine for blank repos, but if this should match an existing template add --template <owner>/<repo>.")
fi

# gh pr merge without an explicit strategy. Project standard is --squash.
if printf '%s' "$ACTUAL" | grep -qE '^gh[[:space:]]+pr[[:space:]]+merge\b' \
   && ! printf '%s' "$ACTUAL" | grep -qE '([[:space:]]|^)--(squash|merge|rebase)([[:space:]]|$)'; then
  WARNINGS+=("gh pr merge without explicit strategy — project standard is --squash. Add it explicitly so the merge style is reviewable in shell history.")
fi

# git push to a protected branch.
if printf '%s' "$ACTUAL" | grep -qE '^git[[:space:]]+push\b' \
   && printf '%s' "$ACTUAL" | grep -qE '\b(main|master|staging|prod|production)\b'; then
  WARNINGS+=("git push targeting a protected branch (main/master/staging/prod). In protected mode, prefer feature branch + PR + auto-merge. Continue only if you intend to bypass.")
fi

# git push --force / --force-with-lease at a protected branch.
if printf '%s' "$ACTUAL" | grep -qE '^git[[:space:]]+push\b' \
   && printf '%s' "$ACTUAL" | grep -qE '([[:space:]]|^)(--force|-f|--force-with-lease)([[:space:]]|$)' \
   && printf '%s' "$ACTUAL" | grep -qE '\b(main|master|staging|prod|production)\b'; then
  WARNINGS+=("Force-push targeting a protected branch — almost never the right move. Triple-check before continuing.")
fi

if [ ${#WARNINGS[@]} -eq 0 ]; then
  exit 0
fi

{
  echo "[gh-workflow] Advisory (non-blocking):"
  printf ' - %s\n' "${WARNINGS[@]}"
} >&2

# Non-blocking — let the command proceed.
exit 0
