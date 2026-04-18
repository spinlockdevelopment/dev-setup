#!/usr/bin/env bash
# create-repo.sh — idempotent org-repo creation via gh REST.
# Usage: create-repo.sh <org> <name> [--public] [--desc "..."]

set -euo pipefail

ORG="${1:-}"; NAME="${2:-}"; shift 2 || true
[[ -n "${ORG}" && -n "${NAME}" ]] || { echo "usage: $0 <org> <name> [--public] [--desc \"...\"]" >&2; exit 2; }

PRIVATE=true
DESC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --public) PRIVATE=false; shift ;;
    --desc)   DESC="$2"; shift 2 ;;
    *)        echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

ok() { printf '\033[0;32m[create-repo]\033[0m %s\n' "$*"; }
die(){ printf '\033[0;31m[create-repo]\033[0m %s\n' "$*" >&2; exit 1; }

command -v gh >/dev/null || die "gh CLI not installed"

if gh api "/repos/${ORG}/${NAME}" >/dev/null 2>&1; then
  ok "${ORG}/${NAME} already exists — skipping"
  exit 0
fi

gh api -X POST "/orgs/${ORG}/repos" \
  -f "name=${NAME}" \
  -f "description=${DESC}" \
  -F "private=${PRIVATE}" \
  -F "has_issues=true" \
  -F "has_projects=false" \
  -F "has_wiki=false" \
  -F "auto_init=true" \
  -f "default_branch=main" \
  >/dev/null

ok "created ${ORG}/${NAME} (private=${PRIVATE})"
