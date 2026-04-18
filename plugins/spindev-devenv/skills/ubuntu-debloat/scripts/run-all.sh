#!/usr/bin/env bash
# Orchestrator — runs every numbered phase in order.
# Pass --verify to run everything in read-only check mode.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

# The 05 phase installs an ephemeral sudoers fragment so later phases don't
# prompt for a password. This trap reverts it on any exit (success, failure,
# Ctrl-C). Skipped in verify mode because 05 doesn't install in that mode.
SUDOERS_FILE="/etc/sudoers.d/ubuntu-debloat"
revert_sudoers() {
    [[ -f "$SUDOERS_FILE" ]] || return 0
    log_step "reverting ephemeral sudoers fragment"
    if sudo -n rm -f "$SUDOERS_FILE" 2>/dev/null; then
        log_ok "removed $SUDOERS_FILE"
    else
        log_fail "could not remove $SUDOERS_FILE (run: sudo rm $SUDOERS_FILE)"
    fi
}
if ! $VERIFY_MODE; then
    trap revert_sudoers EXIT
fi

PHASES=(
    "00-preflight.sh"
    "05-sudoers-nopasswd.sh"
    "10-update.sh"
    "20-debloat.sh"
    "30-remove-snap.sh"
    "40-install-core.sh"
    "50-install-chrome.sh"
    "51-install-brave.sh"
    "60-install-mise.sh"
    "70-install-docker.sh"
    "80-install-android.sh"
    "90-install-vscode.sh"
)

fails=0
for phase in "${PHASES[@]}"; do
    log_step "PHASE: $phase"
    if ! bash "$HERE/$phase" "$@"; then
        log_fail "phase failed: $phase"
        fails=$((fails + 1))
        if ! $VERIFY_MODE; then
            echo "Stopping. Fix the failure and re-run. Scripts are idempotent — " \
                 "re-running run-all.sh will skip completed phases."
            exit 1
        fi
    fi
done

log_step "FINAL VERIFY"
bash "$HERE/99-verify.sh" || fails=$((fails + 1))

echo
if (( fails == 0 )); then
    echo "all phases completed cleanly"
else
    echo "$fails phase(s) reported issues — see above"
    exit 1
fi
