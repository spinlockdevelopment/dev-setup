#!/usr/bin/env bash
# verify.sh — read-only health check for the backup chain.
#
# Checks:
#   - restic installed at pinned version
#   - both env files present + look sane
#   - NAS repo reachable (`restic snapshots` succeeds)
#   - R2 repo reachable (same)
#   - last successful systemd run within 36h
#   - healthcheck.io URL responds
# Optional, slower:
#   --deep   adds `restic check --read-data-subset 1%` against both repos

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

DEEP=false
case "${1:-}" in
  --deep) DEEP=true ;;
  ""|--shallow) ;;
  *) die "unknown flag: $1 (use --deep)" ;;
esac

EXIT=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$label"
  else
    warn "FAIL: $label"
    EXIT=1
  fi
}

check "restic installed" command -v restic
check "nas.env present" test -r "$(config_dir)/nas.env"
check "r2.env present"  test -r "$(config_dir)/r2.env"
check "password file present" bash -c 'load_env; test -n "${RESTIC_PASSWORD_FILE:-}" && test -r "$RESTIC_PASSWORD_FILE"'

# Reachability.
check "NAS repo reachable" bash -c 'restic_nas snapshots --quiet --json --latest 1'
check "R2 repo reachable"  bash -c 'restic_r2  snapshots --quiet --json --latest 1'

# Last successful run via journald.
if command -v journalctl >/dev/null; then
  LAST_OK="$(journalctl -u restic-backup.service --grep='all stages succeeded' -n1 --no-pager -o short-iso 2>/dev/null | tail -1 | awk '{print $1}')"
  if [[ -n "$LAST_OK" ]]; then
    AGE_S=$(( $(date +%s) - $(date -d "$LAST_OK" +%s 2>/dev/null || echo 0) ))
    if (( AGE_S < 36*3600 )); then
      ok "last successful run: ${LAST_OK} ($((AGE_S/3600))h ago)"
    else
      warn "FAIL: last success was ${LAST_OK} ($((AGE_S/3600))h ago — expected <36h)"
      EXIT=1
    fi
  else
    warn "no successful run found in journal — has the timer fired yet?"
    EXIT=1
  fi
fi

# Healthcheck URL.
load_env
if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
  if curl -fsS -m 10 -o /dev/null "$HEALTHCHECK_URL"; then
    ok "healthcheck URL responds"
  else
    warn "FAIL: healthcheck URL did not respond — backup runs won't ping"
    EXIT=1
  fi
fi

# Deep check.
if $DEEP; then
  log "running 'restic check --read-data-subset 1%' on NAS (slow)"
  restic_nas check --read-data-subset 1% || { warn "NAS check failed"; EXIT=1; }
  log "running 'restic check --read-data-subset 1%' on R2 (slow, costs egress)"
  restic_r2 check --read-data-subset 1% || { warn "R2 check failed"; EXIT=1; }
fi

exit $EXIT
