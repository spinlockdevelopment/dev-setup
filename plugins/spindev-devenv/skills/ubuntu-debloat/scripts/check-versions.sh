#!/usr/bin/env bash
# Upstream version drift check.
#
# Compares pinned versions in our scripts against what upstream is currently
# shipping. Reports drift but does NOT auto-edit — Claude decides whether to
# update the scripts based on the drift report.
#
# Exit 0 = no drift, exit 1 = drift detected.
#
# This script intentionally uses only read-only HTTP fetches (curl) + jq.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

drift=0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_step "Version drift check"

# ---- Ubuntu codename sanity ------------------------------------------------
CODENAME=$(lsb_release -cs)
VERSION=$(lsb_release -sr)
log_info "running on Ubuntu $VERSION ($CODENAME)"
# We don't flag drift here; skill just needs to support 24.04+.

# ---- JDK LTS ---------------------------------------------------------------
# Current Adoptium LTS list; the API is public and stable.
# https://api.adoptium.net/v3/info/available_releases
pinned_jdk=$(grep -oP 'JDK_VERSION=\K[0-9]+' "$HERE/80-install-android.sh" | head -1)
latest_jdk=$(curl -fsSL https://api.adoptium.net/v3/info/available_releases 2>/dev/null \
    | jq -r '.most_recent_lts' || echo "")
if [[ -z "$latest_jdk" ]]; then
    log_fail "could not fetch Adoptium LTS info"
elif [[ "$pinned_jdk" != "$latest_jdk" ]]; then
    log_fail "JDK: pinned $pinned_jdk, upstream LTS is $latest_jdk → bump 80-install-android.sh"
    drift=$((drift + 1))
else
    log_ok "JDK LTS pin current: $pinned_jdk"
fi

# ---- Android Studio --------------------------------------------------------
# Tarball filename is now codename-based (e.g. "android-studio-panda3-patch1-
# linux.tar.gz"), so we pull the version from the URL path "/ide-zips/<ver>/"
# instead of the filename. Updated regex on 2026-04-13.
pinned_studio=$(grep -oP 'STUDIO_VERSION="\K[^"]+' "$HERE/80-install-android.sh" | head -1)
latest_studio=$(curl -fsSL https://developer.android.com/studio 2>/dev/null \
    | grep -oE '/android/studio/ide-zips/[0-9.]+/android-studio-[^"]+-linux\.tar\.gz' \
    | head -1 \
    | sed -E 's|.*/ide-zips/([0-9.]+)/.*|\1|' || echo "")
if [[ -z "$latest_studio" ]]; then
    log_fail "could not determine latest Android Studio version"
elif [[ "$pinned_studio" != "$latest_studio" ]]; then
    log_fail "Android Studio: pinned $pinned_studio, upstream is $latest_studio → bump 80-install-android.sh"
    drift=$((drift + 1))
else
    log_ok "Android Studio pin current: $pinned_studio"
fi

# ---- mise-managed toolchains (Node / Python / Go) --------------------------
# These resolve at install time via 'node@lts', 'python@3', etc., so there's
# no pin to drift. Just verify the local install tracks current LTS / stable.
MISE_BIN="${HOME}/.local/bin/mise"
if [[ -x "$MISE_BIN" ]]; then
    for t in node python go java; do
        installed=$("$MISE_BIN" current "$t" 2>/dev/null || true)
        latest=$("$MISE_BIN" latest "$t" 2>/dev/null || true)
        if [[ -n "$installed" && -n "$latest" && "$installed" != "$latest" ]]; then
            log_info "mise $t: installed $installed, latest $latest (run 'mise upgrade $t' if desired)"
        elif [[ -n "$installed" ]]; then
            log_ok "mise $t: $installed"
        fi
    done
fi

# ---- Ubuntu LTS rollover note ---------------------------------------------
# When a new LTS ships (even-year April), warn about 00-preflight.sh's gate.
current_lts_major=$(echo "$VERSION" | cut -d. -f1)
if (( current_lts_major > 24 )); then
    log_fail "running on Ubuntu $VERSION — confirm scripts are still compatible and update 00-preflight.sh floor if needed"
    drift=$((drift + 1))
fi

echo
if (( drift == 0 )); then
    log_ok "no version drift detected"
    exit 0
else
    log_fail "$drift pin(s) are behind upstream — see messages above"
    echo
    echo "Claude: per the self-healing section of SKILL.md, edit the affected"
    echo "script to bump the pinned value, leave a dated comment, then re-run"
    echo "the script to verify the new version works."
    exit 1
fi
