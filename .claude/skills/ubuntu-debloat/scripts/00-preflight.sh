#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "Preflight: OS gate + package snapshot"

require_ubuntu
log_ok "Ubuntu $(lsb_release -sr) ($(lsb_release -sc))"

# Snapshot of manually-installed packages, written once per run.
SNAP_DIR="${HOME}/.local/state/ubuntu-debloat"
mkdir -p "$SNAP_DIR"
SNAP_FILE="$SNAP_DIR/pkg-snapshot-$(date +%Y%m%d-%H%M%S).txt"

if $VERIFY_MODE; then
    if ls "$SNAP_DIR"/pkg-snapshot-*.txt &>/dev/null; then
        log_ok "package snapshots present in $SNAP_DIR"
    else
        log_fail "no package snapshots found in $SNAP_DIR"
        exit 1
    fi
else
    apt-mark showmanual > "$SNAP_FILE"
    log_ok "package snapshot written: $SNAP_FILE"
fi

# Install prerequisites used by later scripts.
apt_install curl ca-certificates gpg lsb-release
