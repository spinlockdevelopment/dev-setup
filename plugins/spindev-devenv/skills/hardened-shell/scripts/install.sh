#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "install hshell launcher"

SKILL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${SKILL_DIR}/scripts/hshell"
DST="${HOME}/.local/bin/hshell"
DST_DIR="$(dirname "$DST")"

if [[ ! -x "$SRC" ]]; then
    log_fail "launcher not found or not executable: $SRC"
    exit 1
fi

# Verify mode — read-only check.
if [[ "${1-}" == "--verify" ]]; then
    if [[ -L "$DST" ]] && [[ "$(readlink -f "$DST")" == "$(readlink -f "$SRC")" ]]; then
        log_ok "hshell installed → $DST"
        exit 0
    fi
    log_fail "hshell not installed or points elsewhere (expected symlink to $SRC)"
    exit 1
fi

# Check existing state.
if [[ -L "$DST" ]] && [[ "$(readlink -f "$DST")" == "$(readlink -f "$SRC")" ]]; then
    log_skip "hshell already installed → $DST"
    exit 0
fi

if [[ -e "$DST" && ! -L "$DST" ]]; then
    log_fail "$DST exists and is not a symlink; refusing to overwrite"
    exit 1
fi

# Warn if ~/.local/bin isn't on PATH — Ubuntu 24.04 adds it via /etc/profile.d,
# but other distros may not. No need to fail; just tell the user.
case ":${PATH}:" in
    *":${DST_DIR}:"*) ;;
    *) log_info "note: $DST_DIR is not on your PATH — add it to use 'hshell' without a full path" ;;
esac

mkdir -p "$DST_DIR"
log_info "symlinking $SRC → $DST"
ln -sf "$SRC" "$DST"
log_ok "installed: $DST"
