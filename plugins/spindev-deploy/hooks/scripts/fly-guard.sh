#!/usr/bin/env bash
# fly-guard — PreToolUse hook for the flyio skill.
#
# Catches the documented gotchas in
# plugins/spindev-deploy/skills/flyio/SKILL.md before flyctl runs.
# Blocks destructive ops without explicit ack, env vars under the
# silently-stripped VAULT_ prefix, and malformed app names. Advises
# (does not block) on `fly deploy` without --remote-only.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Bash" ] || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

# Strip leading env-var assignments so the matcher sees the real cmd.
ACTUAL=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+//')

case "$ACTUAL" in
  fly|fly\ *|flyctl|flyctl\ *) ;;
  *) exit 0 ;;
esac

VIOLATIONS=()
WARNINGS=()

# Destructive subcommands require --yes / -y.
if printf '%s' "$ACTUAL" | grep -qE '^fly(ctl)?[[:space:]]+(apps|volumes|machines)[[:space:]]+destroy\b'; then
  if ! printf '%s' "$ACTUAL" | grep -qE '([[:space:]]|^)(--yes|-y)([[:space:]]|$)'; then
    VIOLATIONS+=("Destructive fly command requires explicit --yes. Confirm with the operator first, then add --yes.")
  fi
fi

# Token revoke is destructive too — same rule.
if printf '%s' "$ACTUAL" | grep -qE '^fly(ctl)?[[:space:]]+tokens[[:space:]]+revoke\b'; then
  if ! printf '%s' "$ACTUAL" | grep -qE '([[:space:]]|^)(--yes|-y)([[:space:]]|$)'; then
    VIOLATIONS+=("Token revocation needs explicit --yes — verify the new token works first, then add --yes.")
  fi
fi

# fly secrets set with a VAULT_-prefixed key — silently stripped at runtime.
if printf '%s' "$ACTUAL" | grep -qE '^fly(ctl)?[[:space:]]+secrets[[:space:]]+set\b' \
   && printf '%s' "$ACTUAL" | grep -qE '\bVAULT_[A-Z0-9_]+='; then
  VIOLATIONS+=("Fly silently strips env vars with the VAULT_ prefix at runtime. Pick a different prefix — see flyio SKILL.md gotchas.")
fi

# fly apps create — name must be lowercase alphanumeric + hyphens only.
if printf '%s' "$ACTUAL" | grep -qE '^fly(ctl)?[[:space:]]+apps[[:space:]]+create\b'; then
  NAME=$(printf '%s' "$ACTUAL" | sed -nE 's/^fly(ctl)?[[:space:]]+apps[[:space:]]+create[[:space:]]+([^-[:space:]][^[:space:]]*).*/\2/p')
  if [ -n "$NAME" ] && printf '%s' "$NAME" | grep -qE '[^a-z0-9-]'; then
    VIOLATIONS+=("App name '$NAME' has invalid chars — fly requires lowercase alphanumeric + hyphens only (no dots, caps, underscores).")
  fi
fi

# fly deploy — recommend --remote-only (advisory, not blocking).
if printf '%s' "$ACTUAL" | grep -qE '^fly(ctl)?[[:space:]]+deploy\b' \
   && ! printf '%s' "$ACTUAL" | grep -qE '([[:space:]]|^)--remote-only([[:space:]]|$)'; then
  WARNINGS+=("Consider 'fly deploy --remote-only' to build on fly's infrastructure rather than locally.")
fi

if [ ${#VIOLATIONS[@]} -gt 0 ]; then
  {
    echo "[fly-guard] Blocked. Fix and retry:"
    printf ' - %s\n' "${VIOLATIONS[@]}"
    if [ ${#WARNINGS[@]} -gt 0 ]; then
      echo
      echo "Also:"
      printf ' - %s\n' "${WARNINGS[@]}"
    fi
    echo "Reference: plugins/spindev-deploy/skills/flyio/SKILL.md"
  } >&2
  exit 2
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  {
    echo "[fly-guard] Advisory:"
    printf ' - %s\n' "${WARNINGS[@]}"
  } >&2
fi

exit 0
