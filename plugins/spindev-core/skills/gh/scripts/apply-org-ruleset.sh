#!/usr/bin/env bash
# apply-org-ruleset.sh — idempotent "protect-release-branches" ruleset
# on an org (main/staging/prod, all repos, no force-push, no deletion,
# PR required, no bypass actors).
#
# Requires GitHub Team plan on the org. Fails with "Upgrade to GitHub
# Team" if not.
#
# Usage:
#   apply-org-ruleset.sh <org>                # create or update
#   apply-org-ruleset.sh <org> --verify       # read-only check
#   apply-org-ruleset.sh <org> --delete       # remove (with confirm)

set -euo pipefail

ORG="${1:-}"
MODE="${2:-apply}"
[[ -n "${ORG}" ]] || { echo "usage: $0 <org> [--verify|--delete]" >&2; exit 2; }
case "${MODE}" in --verify|--delete|apply|'') ;; *) echo "unknown mode: ${MODE}" >&2; exit 2 ;; esac

RULESET_NAME="protect-release-branches"

log()  { printf '\033[0;34m[ruleset:%s]\033[0m %s\n' "${ORG}" "$*"; }
ok()   { printf '\033[0;32m[ruleset:%s]\033[0m %s\n' "${ORG}" "$*"; }
die()  { printf '\033[0;31m[ruleset:%s]\033[0m %s\n' "${ORG}" "$*" >&2; exit 1; }

command -v gh >/dev/null || die "gh CLI not installed"
command -v python3 >/dev/null || die "python3 required"

body_for() {
  local name="$1"
  python3 -c '
import json, sys
print(json.dumps({
  "name": sys.argv[1],
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {"include": ["~DEFAULT_BRANCH", "refs/heads/staging", "refs/heads/prod"], "exclude": []},
    "repository_name": {"include": ["~ALL"], "exclude": [], "protected": False}
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 0,
      "dismiss_stale_reviews_on_push": False,
      "require_code_owner_review": False,
      "require_last_push_approval": False,
      "required_review_thread_resolution": False,
      "allowed_merge_methods": ["merge", "squash", "rebase"]
    }}
  ]
}))' "$name"
}

list_or_die() {
  local out
  out="$(gh api "/orgs/${ORG}/rulesets" 2>&1)" || true
  if [[ "${out}" == *"Upgrade to GitHub Team"* ]]; then
    die "org '${ORG}' is on Free — rulesets require Team or higher"
  fi
  printf '%s' "${out}"
}

find_id() {
  list_or_die | python3 -c "
import json,sys
for r in json.load(sys.stdin):
  if r.get('name')=='${RULESET_NAME}': print(r['id']); break"
}

case "${MODE}" in
  --verify)
    log "checking plan access"
    list_or_die >/dev/null
    ok "rulesets API reachable"
    id="$(find_id || true)"
    if [[ -n "${id}" ]]; then ok "ruleset exists (id=${id})"
    else log "ruleset '${RULESET_NAME}' does not exist"; fi
    ;;
  --delete)
    id="$(find_id || true)"
    [[ -n "${id}" ]] || { ok "nothing to delete"; exit 0; }
    read -r -p "type DELETE to remove ruleset ${id}: " c; [[ "${c}" == DELETE ]] || die "aborted"
    gh api -X DELETE "/orgs/${ORG}/rulesets/${id}" >/dev/null
    ok "deleted ${id}"
    ;;
  apply|'')
    id="$(find_id || true)"
    if [[ -n "${id}" ]]; then
      log "updating id=${id}"
      body_for "${RULESET_NAME}" | gh api -X PUT "/orgs/${ORG}/rulesets/${id}" --input - >/dev/null
      ok "updated id=${id}"
    else
      log "creating"
      new="$(body_for "${RULESET_NAME}" | gh api -X POST "/orgs/${ORG}/rulesets" --input - 2>&1)" \
        || { [[ "${new}" == *"Upgrade to GitHub Team"* ]] \
               && die "org '${ORG}' is on Free — upgrade required" \
               || die "create failed: ${new}"; }
      ok "created: $(printf '%s' "${new}" | python3 -c 'import json,sys;print("id="+str(json.load(sys.stdin)["id"]))')"
    fi
    ;;
esac
