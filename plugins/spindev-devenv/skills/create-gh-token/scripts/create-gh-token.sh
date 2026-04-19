#!/usr/bin/env bash
# create-gh-token — validate a fine-grained GitHub PAT and wire it into the
# current project's HTTPS git remote so pushes work without a credential
# prompt. Token lives only in .git/config (local, never pushed).
#
# Usage:
#   ./create-gh-token.sh                      paste token, validate, rewrite remote (default: origin)
#   ./create-gh-token.sh --remote upstream    rewrite a different remote
#   ./create-gh-token.sh --no-set-remote      validate only; don't touch .git/config
#   ./create-gh-token.sh --verify             check that the current remote works
#   ./create-gh-token.sh -h                   help
#
# Idempotent: re-running with a fresh token rotates the embedded credential.
# Never echoes the token to stdout. Reads token from a silent prompt or stdin.

set -euo pipefail

REMOTE="origin"
SET_REMOTE="yes"
MODE="interactive"

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

log()  { printf '\033[0;34m[create-gh-token]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[create-gh-token]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[create-gh-token]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31m[create-gh-token]\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)        REMOTE="${2:?--remote needs a value}"; shift 2 ;;
    --no-set-remote) SET_REMOTE="no"; shift ;;
    --verify)        MODE="verify"; shift ;;
    -h|--help)       usage; exit 0 ;;
    *)               die "unknown arg: $1 (try --help)" ;;
  esac
done

need git
need curl
need python3

# 1. cd to repo root so .git/config edits hit the right place.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "not inside a git repository (cd into your project first)"
cd "${REPO_ROOT}"

# 2. read the remote URL.
URL="$(git remote get-url "${REMOTE}" 2>/dev/null)" \
  || die "no remote named '${REMOTE}' (try --remote <name>)"

# 3. parse owner / repo from either SSH or HTTPS GitHub URLs.
parse_owner_repo() {
  local url="$1" owner repo
  case "${url}" in
    git@github.com:*)
      url="${url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      url="${url#ssh://git@github.com/}"
      ;;
    https://*@github.com/*)
      url="${url#https://*@github.com/}"
      ;;
    https://github.com/*)
      url="${url#https://github.com/}"
      ;;
    *)
      die "remote '${REMOTE}' is not a github.com URL: ${url}"
      ;;
  esac
  url="${url%.git}"
  owner="${url%%/*}"
  repo="${url#*/}"
  repo="${repo%%/*}"
  [[ -n "${owner}" && -n "${repo}" ]] \
    || die "could not parse owner/repo from: $1"
  printf '%s\n%s\n' "${owner}" "${repo}"
}

mapfile -t parts < <(parse_owner_repo "${URL}")
OWNER="${parts[0]}"
REPO="${parts[1]}"
log "remote ${REMOTE} → ${OWNER}/${REPO}"

# Helper: extract a JSON field with python3 (already a hard dep).
json_field() {
  python3 -c 'import json,sys;print(json.load(sys.stdin).get("'"$1"'", ""))'
}

# Helper: validate a token against /user and /repos/<owner>/<repo>.
# Echoes the authenticated login on success; dies on failure.
validate_token() {
  local token="$1" who repo_full
  who="$(curl -fsS -H "Authorization: Bearer ${token}" \
                  -H "Accept: application/vnd.github+json" \
                  https://api.github.com/user 2>/dev/null \
        | json_field login)" \
    || die "token rejected by GitHub at /user (bad / expired / revoked, or network down)"
  [[ -n "${who}" ]] || die "GitHub returned no login for this token"

  repo_full="$(curl -fsS -H "Authorization: Bearer ${token}" \
                          -H "Accept: application/vnd.github+json" \
                          "https://api.github.com/repos/${OWNER}/${REPO}" 2>/dev/null \
              | json_field full_name)" \
    || die "token does NOT have access to ${OWNER}/${REPO} — check the Resource owner and 'Only select repositories' list at https://github.com/settings/personal-access-tokens"
  [[ "${repo_full}" == "${OWNER}/${REPO}" ]] \
    || die "GitHub returned unexpected repo full_name '${repo_full}' (expected ${OWNER}/${REPO})"

  printf '%s' "${who}"
}

# --- verify mode: do not read a token. Just probe the existing remote. ---
if [[ "${MODE}" == "verify" ]]; then
  log "probing ${REMOTE} with git ls-remote..."
  if git ls-remote "${REMOTE}" >/dev/null 2>&1; then
    ok "remote '${REMOTE}' is reachable and credentials work"
    exit 0
  else
    die "git ls-remote failed for '${REMOTE}' — re-run without --verify to wire a new token"
  fi
fi

# --- interactive mode: read token, validate, optionally rewrite. ---
cat <<EOF

To create the token, follow the checklist in this skill's README.md
(or the Claude-driven flow). When you have the token copied:

EOF

TOKEN=""
if [[ -t 0 ]]; then
  read -r -s -p "Paste fine-grained PAT (input hidden, Enter when done): " TOKEN || true
  echo
else
  read -r TOKEN || true
fi
[[ -n "${TOKEN}" ]] || die "no token provided"

# Strip stray whitespace some terminals append on paste.
TOKEN="${TOKEN//[$'\t\r\n ']}"

case "${TOKEN}" in
  github_pat_*) : ;;  # expected: fine-grained PAT
  ghp_*)
    warn "this looks like a CLASSIC PAT (ghp_…). It will work, but you lose per-repo scoping. Consider a fine-grained token (github_pat_…) instead."
    ;;
  ghs_*|gho_*|ghr_*|ghu_*)
    warn "this looks like a server-issued token (${TOKEN:0:4}…), not a PAT you'd paste here. Continuing, but expect failure."
    ;;
  *)
    warn "token doesn't match any known GitHub prefix. Continuing, but validation will catch it if it's bad."
    ;;
esac

log "validating token against GitHub..."
LOGIN="$(validate_token "${TOKEN}")"
ok "token validated: authenticated as ${LOGIN}, ${OWNER}/${REPO} accessible"

if [[ "${SET_REMOTE}" == "no" ]]; then
  ok "validation only (--no-set-remote); .git/config untouched"
  exit 0
fi

# Rewrite the remote URL with the embedded credential.
NEW_URL="https://x-access-token:${TOKEN}@github.com/${OWNER}/${REPO}.git"
git remote set-url "${REMOTE}" "${NEW_URL}"
ok "rewrote remote '${REMOTE}' → https://x-access-token:***@github.com/${OWNER}/${REPO}.git"

log "confirming with git ls-remote..."
if git ls-remote "${REMOTE}" >/dev/null 2>&1; then
  ok "git push will now work without a credential prompt"
else
  die "git ls-remote failed after rewrite — token may lack Contents:Read+write on this repo"
fi

cat <<EOF

Done. Token is stored only in .git/config (local, not pushed).
Rotate later by re-running this script with a fresh token.
Verify anytime with: $(basename "$0") --verify
EOF
