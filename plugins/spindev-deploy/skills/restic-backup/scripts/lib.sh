#!/usr/bin/env bash
# Shared helpers for restic-backup skill scripts.

set -euo pipefail

ok()   { printf '\033[0;32m[restic]\033[0m %s\n' "$*"; }
log()  { printf '\033[0;34m[restic]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[restic]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31m[restic]\033[0m %s\n' "$*" >&2; exit 1; }

require_cmd() {
  for c in "$@"; do
    command -v "$c" >/dev/null || die "missing command: $c"
  done
}

config_dir() {
  echo "${HOME}/.config/restic-backup"
}

ensure_config_dir() {
  local d
  d="$(config_dir)"
  mkdir -p "$d"
  chmod 700 "$d"
}

# Source the env files that hold creds. Each script that talks to a
# repo should call this first.
load_env() {
  local d
  d="$(config_dir)"
  # shellcheck source=/dev/null
  [[ -r "$d/nas.env" ]] && source "$d/nas.env"
  # shellcheck source=/dev/null
  [[ -r "$d/r2.env" ]]  && source "$d/r2.env"
  # shellcheck source=/dev/null
  [[ -r "$d/healthcheck.env" ]] && source "$d/healthcheck.env"
}

# Run restic against the NAS repo.
restic_nas() {
  load_env
  : "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE not set — run init-repos.sh}"
  : "${NAS_REPO_URL:?NAS_REPO_URL not set — run init-repos.sh}"
  RESTIC_REPOSITORY="$NAS_REPO_URL" restic "$@"
}

# Run restic against the R2 repo.
restic_r2() {
  load_env
  : "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE not set}"
  : "${R2_REPO_URL:?R2_REPO_URL not set — run init-repos.sh}"
  : "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID not set in r2.env}"
  : "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY not set in r2.env}"
  RESTIC_REPOSITORY="$R2_REPO_URL" restic "$@"
}
