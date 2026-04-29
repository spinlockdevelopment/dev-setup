#!/usr/bin/env bash
# create-repo.sh — create an on-prem-only repo on the local Forgejo.
# These repos are NOT mirrored — Forgejo + restic are the entire
# durability story.
#
# Usage:
#   create-repo.sh <name> [--public]
#   create-repo.sh side-project              # private (default)
#   create-repo.sh open-thing --public       # public on this Forgejo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd curl python3

NAME="${1:-}"
[[ -n "$NAME" ]] || die "usage: create-repo.sh <name> [--public]"

PRIVATE="true"
case "${2:-}" in
  --public)  PRIVATE="false" ;;
  --private|"") ;;
  *) die "unknown flag: $2 (use --public or --private)" ;;
esac

ADMIN_USER="$(read_admin_user)"

BODY="$(python3 -c "
import json
print(json.dumps({
  'name': '$NAME',
  'private': $PRIVATE,
  'auto_init': False,
  'default_branch': 'main',
  'description': 'On-prem-only repository.'
}))
")"

RESP="$(api POST /user/repos -d "$BODY" -w '\n%{http_code}')"
HTTP_CODE="$(echo "$RESP" | tail -n1)"
BODY="$(echo "$RESP" | sed '$d')"

case "$HTTP_CODE" in
  201) ok "repo created" ;;
  409) log "repo ${ADMIN_USER}/${NAME} already exists — leaving as-is" ;;
  *)   die "create failed (HTTP $HTTP_CODE): $BODY" ;;
esac

# Pull SSH clone URL from the API rather than guessing port.
SSH_URL="$(api GET "/repos/${ADMIN_USER}/${NAME}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ssh_url",""))')"

ok "repo: $(read_base_url)/${ADMIN_USER}/${NAME}"
ok "clone:"
echo "    git remote add forgejo ${SSH_URL}"
echo "    git push -u forgejo \$(git symbolic-ref --short HEAD)"
echo
warn "this repo is NOT mirrored to GitHub. forgejo + restic are the only copies."
warn "ensure scripts/restic-backup is configured before pushing real work."
