#!/usr/bin/env bash
# sprite-guard — PreToolUse hook for the sprites-dev skill.
#
# Catches the failure modes documented in
# plugins/spindev-deploy/skills/sprites-dev/SKILL.md before the bash
# command actually runs. Universal rules fire on every platform;
# Windows/Git-Bash-specific rules only fire when uname says we're
# there.
#
# Exits with 2 + stderr message to block; exit 0 to allow.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Bash" ] || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

# Strip leading env-var assignments (e.g. `MSYS_NO_PATHCONV=1 sprite api ...`)
# so the rule matchers see the actual command.
ACTUAL=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+//')

case "$ACTUAL" in
  sprite|sprite\ *) ;;
  *) exit 0 ;;
esac

case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
  *) IS_WINDOWS=0 ;;
esac

VIOLATIONS=()

# Rule 1 (universal best practice): `sprite exec -- <cmd>` should wrap in bash -c
# so the remote shell owns parsing. Bare flags get misinterpreted by sprite.
if printf '%s' "$ACTUAL" | grep -qE '^sprite[[:space:]]+exec\b'; then
  AFTER=$(printf '%s' "$ACTUAL" | sed -nE 's/.*[[:space:]]--[[:space:]]+(.+)$/\1/p')
  if [ -n "$AFTER" ]; then
    FIRST=$(printf '%s' "$AFTER" | awk '{print $1}')
    case "$FIRST" in
      bash|/bin/bash|sh|/bin/sh) ;;
      *) VIOLATIONS+=("sprite exec must wrap commands in bash -c \"...\" so the remote shell owns flag parsing — see sprites-dev SKILL.md rule 1.") ;;
    esac
  fi
fi

# Rule 2 (Windows only): `sprite api /...` needs MSYS_NO_PATHCONV=1
# or Git Bash mangles the URL path.
if [ "$IS_WINDOWS" = "1" ] && printf '%s' "$ACTUAL" | grep -qE '^sprite[[:space:]]+api[[:space:]]+/'; then
  if ! printf '%s' "$CMD" | grep -qE '\bMSYS_NO_PATHCONV=1\b'; then
    VIOLATIONS+=("On Git Bash, prefix sprite api calls with MSYS_NO_PATHCONV=1 — sprites-dev SKILL.md rule 2.")
  fi
fi

# Rule 3 (universal): sprite api <path> -- <curl-flags>. Curl flags
# in front of the path get parsed as sprite flags.
if printf '%s' "$ACTUAL" | grep -qE '^sprite[[:space:]]+api[[:space:]]+(-X|-H|-d|-F|-u|--data|--header)\b'; then
  VIOLATIONS+=("sprite api flag order is: api <path> -- <curl-flags>. Move -X/-H/-d after the path and the literal -- separator — sprites-dev SKILL.md rule 3.")
fi

# Rule 6 (Windows only): --dir absolute paths get path-mangled.
# Tell the user to cd inside bash -c instead.
if [ "$IS_WINDOWS" = "1" ] && printf '%s' "$ACTUAL" | grep -qE '^sprite[[:space:]]+exec\b.*[[:space:]]--dir[[:space:]]+/'; then
  VIOLATIONS+=("--dir absolute paths get mangled on Git Bash. Drop --dir and 'cd' inside the bash -c wrapper — sprites-dev SKILL.md rule 6.")
fi

if [ ${#VIOLATIONS[@]} -eq 0 ]; then
  exit 0
fi

{
  echo "[sprite-guard] Blocked. Fix and retry:"
  printf ' - %s\n' "${VIOLATIONS[@]}"
  echo "Reference: plugins/spindev-deploy/skills/sprites-dev/SKILL.md"
} >&2
exit 2
