#!/usr/bin/env bash
# restore-drill.sh — pull the latest snapshot for a tag from the NAS,
# restore to a scratch dir, and sanity-check it. The point: prove the
# chain actually works end-to-end. Untested backups are not backups.
#
# Usage:
#   restore-drill.sh                                    # latest 'forgejo' snapshot → /tmp/restic-drill
#   restore-drill.sh --tag projects --dest /tmp/d
#   restore-drill.sh --from r2                          # exercise R2 leg (costs nothing — R2 egress is free)
#
# Sanity checks performed on restored content:
#   - directory exists, non-empty
#   - any bare git repos found (*.git/) pass `git fsck --no-progress`

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

TAG="forgejo"
DEST="/tmp/restic-drill"
FROM="nas"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)  TAG="$2"; shift 2 ;;
    --dest) DEST="$2"; shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

case "$FROM" in
  nas|NAS) RESTIC=restic_nas ;;
  r2|R2)   RESTIC=restic_r2 ;;
  *) die "--from must be 'nas' or 'r2'" ;;
esac

require_cmd restic git

mkdir -p "$DEST"
log "restoring latest '${TAG}' snapshot from ${FROM} → ${DEST}"

# `restore latest` plus tag filter pulls just the latest snapshot
# matching the tag. --target sets the dest.
"$RESTIC" restore latest --tag "$TAG" --target "$DEST" --verbose=1

log "restored — running sanity checks"

if [[ -z "$(ls -A "$DEST")" ]]; then
  die "FAIL: restore directory is empty"
fi
ok "restore directory is non-empty"

# Find bare repos and fsck them. Forgejo stores them under
# data/forgejo/git/repositories/<owner>/<repo>.git.
mapfile -t BARE_REPOS < <(find "$DEST" -maxdepth 8 -type d -name '*.git' 2>/dev/null)

if (( ${#BARE_REPOS[@]} == 0 )); then
  log "no bare git repos found inside the restore — skipping git fsck"
else
  log "found ${#BARE_REPOS[@]} bare repos — running git fsck on each"
  FAILS=0
  for r in "${BARE_REPOS[@]}"; do
    if git --git-dir="$r" fsck --no-progress --no-dangling >/dev/null 2>&1; then
      ok "fsck OK: ${r#$DEST/}"
    else
      warn "FAIL: ${r#$DEST/}"
      ((FAILS++))
    fi
  done
  if (( FAILS > 0 )); then
    die "${FAILS} repos failed git fsck — backup is corrupt or this snapshot is broken"
  fi
fi

ok "drill complete. wipe scratch with: rm -rf ${DEST}"
