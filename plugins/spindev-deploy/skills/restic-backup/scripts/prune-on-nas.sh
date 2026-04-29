#!/usr/bin/env bash
# prune-on-nas.sh — retention enforcer. RUN THIS ON THE NAS BOX.
#
# The source box's rest-server credentials are append-only and the R2
# token is write-only — neither can `forget` or `prune`. That's the
# immutability guarantee. Retention has to come from a different
# privileged context.
#
# This script expects:
#   - to run ON THE NAS (so it can hit the restic data dir directly
#     via the local filesystem, bypassing the append-only rest-server)
#   - a copy of the restic password (same one as on the source box)
#   - optionally, a separate R2 token with DeleteObject scope, to
#     prune the R2 leg
#
# Usage:
#   prune-on-nas.sh                       # NAS only, no R2
#   prune-on-nas.sh --also-r2             # also prune R2 (needs delete-capable token)
#
# Safe cadence: monthly. Restic dedup keeps growth slow without it.

set -euo pipefail

ok()   { printf '\033[0;32m[prune]\033[0m %s\n' "$*"; }
log()  { printf '\033[0;34m[prune]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[prune]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31m[prune]\033[0m %s\n' "$*" >&2; exit 1; }

ALSO_R2=false
case "${1:-}" in
  --also-r2) ALSO_R2=true ;;
  ""|--nas-only) ;;
  *) die "unknown flag: $1 (use --also-r2 or --nas-only)" ;;
esac

# Defaults — override with env.
NAS_REPO_PATH="${NAS_REPO_PATH:-/srv/restic}"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/etc/rest-server/restic-password}"
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-12}"

[[ -d "$NAS_REPO_PATH" ]] || die "NAS repo path not found: ${NAS_REPO_PATH}"
[[ -r "$RESTIC_PASSWORD_FILE" ]] || die "password file unreadable: ${RESTIC_PASSWORD_FILE}"

command -v restic >/dev/null || die "restic not installed on this NAS — install it first"

export RESTIC_PASSWORD_FILE

# ─── NAS leg: forget + prune via local filesystem ──────────────────
log "NAS forget+prune at ${NAS_REPO_PATH} (keep ${KEEP_DAILY}d/${KEEP_WEEKLY}w/${KEEP_MONTHLY}m)"
restic -r "$NAS_REPO_PATH" forget \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --group-by tags \
  --prune
ok "NAS retention applied"

# ─── R2 leg (optional, requires elevated token) ────────────────────
if $ALSO_R2; then
  : "${R2_REPO_URL:?R2_REPO_URL not set in env (point at the same R2 repo)}"
  : "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID not set (use a Delete-capable R2 token here, NOT the source-box one)}"
  : "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY not set}"

  log "R2 forget+prune at ${R2_REPO_URL}"
  RESTIC_REPOSITORY="$R2_REPO_URL" restic forget \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY" \
    --group-by tags \
    --prune
  ok "R2 retention applied"
else
  log "R2 leg untouched. To prune R2, re-run with --also-r2 and a"
  log "Delete-capable R2 token in env (do NOT use the source-box token)."
fi

ok "done"
