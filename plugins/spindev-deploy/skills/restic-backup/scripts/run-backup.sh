#!/usr/bin/env bash
# run-backup.sh — the daily backup runner. Called by the systemd
# unit; runnable by hand for ad-hoc runs.
#
# Pipeline (the source box only WRITES — never deletes):
#   for each source in sources.list:
#     restic backup <path> --tag <tag> → NAS
#   restic copy NAS → R2  (single-shot, dedup-preserving)
#   ping healthchecks.io on success
#
# Retention (forget + prune) is INTENTIONALLY not run here. Both the
# NAS rest-server (--append-only) and the R2 token (PutObject-only)
# refuse DELETE by design — that's the immutability guarantee. To
# enforce retention, run scripts/prune-on-nas.sh ON THE NAS BOX with
# write access to the repo, on whatever cadence you prefer (monthly
# is fine; restic dedup keeps unbounded growth slow).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

CFG="$(config_dir)"
SOURCES="${CFG}/sources.list"

[[ -r "$SOURCES" ]] || die "sources list missing at ${SOURCES} — run init-repos.sh"

load_env
: "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE not set — run init-repos.sh}"

EXIT=0
START_EPOCH="$(date +%s)"

ping_hc() {
  local suffix="${1:-}"
  [[ -n "${HEALTHCHECK_URL:-}" ]] || return 0
  curl -fsS -m 10 --retry 3 -o /dev/null "${HEALTHCHECK_URL}${suffix}" || true
}

ping_hc /start

# ─── 1. Snapshot every source to NAS ────────────────────────────────
while IFS=$'\t ' read -r SRC TAG; do
  case "$SRC" in
    ""|\#*) continue ;;
  esac
  if [[ ! -d "$SRC" ]]; then
    warn "source missing, skipping: ${SRC}"
    EXIT=1
    continue
  fi
  log "backing up ${SRC} (tag: ${TAG}) → NAS"
  if ! restic_nas backup "$SRC" --tag "$TAG" --host "$(hostname -s)" --verbose=1; then
    warn "FAIL: NAS backup of ${SRC}"
    EXIT=1
  fi
done < "$SOURCES"

# ─── 2. Copy snapshots NAS → R2 ─────────────────────────────────────
log "copying NAS → R2 (incremental, dedup-preserving)"
if ! restic_r2 copy --from-repo "${NAS_REPO_URL}" --from-password-file "$RESTIC_PASSWORD_FILE" --verbose=1; then
  warn "FAIL: NAS → R2 copy"
  EXIT=1
fi

DURATION=$(( $(date +%s) - START_EPOCH ))
log "run finished in ${DURATION}s"

if [[ $EXIT -eq 0 ]]; then
  ok "all stages succeeded"
  ping_hc
else
  warn "some stages FAILED — see warnings above"
  ping_hc /fail
fi

exit $EXIT
