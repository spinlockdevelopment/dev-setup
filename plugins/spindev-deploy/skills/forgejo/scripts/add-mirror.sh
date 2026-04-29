#!/usr/bin/env bash
# add-mirror.sh — add a GitHub repo as a Forgejo pull-mirror, then
# enable branch protection so the mirror cannot be force-pushed or
# deleted by any client.
#
# Usage:
#   add-mirror.sh <github-url> [interval]
#   add-mirror.sh https://github.com/spinlockdevelopment/dev-setup
#   add-mirror.sh https://github.com/foo/bar 1h
#
# Default interval: 6h. Forgejo accepts Go-duration strings (1h, 30m, 24h).
#
# Idempotent: if the repo already exists in Forgejo's admin user space,
# we patch it to ensure mirror_interval and branch protection match.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd curl python3

GH_URL="${1:-}"
INTERVAL="${2:-6h0m0s}"
[[ -n "$GH_URL" ]] || die "usage: add-mirror.sh <github-url> [interval]"

# Parse owner/repo from URL.
case "$GH_URL" in
  https://github.com/*)
    PATH_PART="${GH_URL#https://github.com/}"
    PATH_PART="${PATH_PART%.git}"
    PATH_PART="${PATH_PART%/}"
    ;;
  git@github.com:*)
    PATH_PART="${GH_URL#git@github.com:}"
    PATH_PART="${PATH_PART%.git}"
    ;;
  *)
    die "unsupported URL format: $GH_URL (expected https://github.com/<user>/<repo> or git@github.com:<user>/<repo>)"
    ;;
esac

REPO_NAME="${PATH_PART##*/}"
[[ -n "$REPO_NAME" ]] || die "could not parse repo name from $GH_URL"

ADMIN_USER="$(read_admin_user)"

log "mirroring ${GH_URL} → ${ADMIN_USER}/${REPO_NAME} (interval ${INTERVAL})"

# 1. Migrate-as-mirror. If repo already exists, the API returns 409 —
#    we treat that as "fine, fall through to patch".
MIGRATE_BODY="$(python3 -c "
import json, sys
print(json.dumps({
  'clone_addr': '$GH_URL',
  'repo_name': '$REPO_NAME',
  'repo_owner': '$ADMIN_USER',
  'mirror': True,
  'mirror_interval': '$INTERVAL',
  'private': False,
  'wiki': False,
  'issues': False,
  'pull_requests': False,
  'releases': True,
  'description': 'Pull-mirror of $GH_URL'
}))
")"

RESP="$(api POST /repos/migrate -d "$MIGRATE_BODY" -w '\n%{http_code}')"
HTTP_CODE="$(echo "$RESP" | tail -n1)"
BODY="$(echo "$RESP" | sed '$d')"

case "$HTTP_CODE" in
  201) ok "repo created as pull-mirror" ;;
  409) log "repo already exists — patching mirror settings" ;;
  *)   die "migrate failed (HTTP $HTTP_CODE): $BODY" ;;
esac

# 2. Patch mirror interval (covers both fresh + existing).
PATCH_BODY="$(python3 -c "
import json
print(json.dumps({
  'mirror_interval': '$INTERVAL',
  'has_wiki': False,
  'has_issues': False,
  'has_pull_requests': False
}))
")"

api PATCH "/repos/${ADMIN_USER}/${REPO_NAME}" -d "$PATCH_BODY" >/dev/null

# 3. Trigger an immediate sync.
api POST "/repos/${ADMIN_USER}/${REPO_NAME}/mirror-sync" -d '{}' >/dev/null
log "triggered immediate sync"

# 4. Find the default branch + lock it down. Forgejo branch protection
#    on a mirror prevents API-side force-push / delete; the periodic
#    pull-mirror itself runs as an internal process and can update
#    refs, but it does so non-destructively (fast-forward only).
DEFAULT_BRANCH="$(api GET "/repos/${ADMIN_USER}/${REPO_NAME}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("default_branch","main"))')"

PROTECT_BODY="$(python3 -c "
import json
print(json.dumps({
  'branch_name': '$DEFAULT_BRANCH',
  'enable_push': False,
  'enable_force_push': False,
  'enable_status_check': False,
  'block_on_outdated_branch': True,
  'block_on_rejected_reviews': False
}))
")"

# POST creates; if it already exists Forgejo returns 409, so we fall
# through to PUT.
PROT_RESP="$(api POST "/repos/${ADMIN_USER}/${REPO_NAME}/branch_protections" -d "$PROTECT_BODY" -w '\n%{http_code}')"
PROT_CODE="$(echo "$PROT_RESP" | tail -n1)"
case "$PROT_CODE" in
  201) ok "branch protection enabled on '${DEFAULT_BRANCH}'" ;;
  409|422)
    api PATCH "/repos/${ADMIN_USER}/${REPO_NAME}/branch_protections/${DEFAULT_BRANCH}" -d "$PROTECT_BODY" >/dev/null
    ok "branch protection updated on '${DEFAULT_BRANCH}'"
    ;;
  *) warn "branch protection setup returned HTTP $PROT_CODE — verify in UI" ;;
esac

ok "mirror ready: $(read_base_url)/${ADMIN_USER}/${REPO_NAME}"
