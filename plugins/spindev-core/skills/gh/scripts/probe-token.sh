#!/usr/bin/env bash
# probe-token.sh — exercise a PAT against read and write endpoints at
# user, org, and repository scopes. Prints which capabilities are
# granted. Safe: no destructive operations.
#
# Usage: probe-token.sh <org>
#   Reads GITHUB_TOKEN or GH_TOKEN from env, falls back to `gh auth token`.

set -euo pipefail

ORG="${1:-}"
[[ -n "${ORG}" ]] || { echo "usage: $0 <org>" >&2; exit 2; }

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}}"
[[ -n "${TOKEN}" ]] || { echo "no token available" >&2; exit 1; }

hit() {
  local method="$1" path="$2" body="${3:-}"
  local code
  if [[ -n "${body}" ]]; then
    code="$(curl -sS -o /dev/null -w "%{http_code}" \
      -X "${method}" -H "Authorization: Bearer ${TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com${path}" -d "${body}")"
  else
    code="$(curl -sS -o /dev/null -w "%{http_code}" \
      -X "${method}" -H "Authorization: Bearer ${TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com${path}")"
  fi
  printf '  %-55s %s\n' "${method} ${path}" "${code}"
}

echo "== user =="
hit GET /user

echo "== org read =="
hit GET "/orgs/${ORG}"

echo "== org administration read (actions permissions) =="
hit GET "/orgs/${ORG}/actions/permissions"

echo "== org administration write (set actions permissions to current value) =="
# Read current first so the PUT is a no-op if we have write.
cur="$(curl -sS -H "Authorization: Bearer ${TOKEN}" \
         -H "Accept: application/vnd.github+json" \
         "https://api.github.com/orgs/${ORG}/actions/permissions" \
       | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("enabled_repositories","all"))')"
hit PUT "/orgs/${ORG}/actions/permissions" "{\"enabled_repositories\":\"${cur}\"}"

echo "== repo admin write (create org repo; probe name that should not exist) =="
hit POST "/orgs/${ORG}/repos" '{"name":"_probe_delete_me","private":true}'

echo "== rulesets (gated on Team plan) =="
hit GET "/orgs/${ORG}/rulesets"

echo
echo "Legend: 200/204 = allowed; 403 'Resource not accessible' = permission missing;"
echo "        403 'Upgrade to GitHub Team' = plan gate; 422 = already exists or invalid body."
