#!/usr/bin/env bash
# Shared helpers for forgejo skill scripts.

set -euo pipefail

ok()   { printf '\033[0;32m[forgejo]\033[0m %s\n' "$*"; }
log()  { printf '\033[0;34m[forgejo]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[forgejo]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31m[forgejo]\033[0m %s\n' "$*" >&2; exit 1; }

require_cmd() {
  for c in "$@"; do
    command -v "$c" >/dev/null || die "missing command: $c"
  done
}

forgejo_dir() {
  echo "${FORGEJO_DIR:-${HOME}/forgejo}"
}

config_dir() {
  echo "${HOME}/.config/forgejo"
}

read_admin_token() {
  local f
  f="$(config_dir)/admin-token"
  [[ -r "$f" ]] || die "admin token missing at $f — run scripts/bootstrap.sh first"
  cat "$f"
}

read_admin_user() {
  local f
  f="$(config_dir)/admin-user"
  [[ -r "$f" ]] || die "admin user file missing at $f — run scripts/bootstrap.sh first"
  cat "$f"
}

read_base_url() {
  local f
  f="$(config_dir)/base-url"
  [[ -r "$f" ]] || die "base-url file missing at $f — run scripts/bootstrap.sh first"
  cat "$f"
}

api() {
  local method="$1" path="$2"
  shift 2
  local base token
  base="$(read_base_url)"
  token="$(read_admin_token)"
  curl -sS -X "$method" \
    -H "Authorization: token ${token}" \
    -H "Content-Type: application/json" \
    "${base}/api/v1${path}" \
    "$@"
}
