#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "hshell health check"

SKILL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER_DST="${HOME}/.local/bin/hshell"

fail=0
step() { "$@" || fail=1; }

# 1. Docker reachable
step require_docker

# 2. Image built
if image_exists; then
    log_ok "image present: ${IMAGE_REF}"
else
    log_fail "image missing: ${IMAGE_REF} — run scripts/build-image.sh"
    fail=1
fi

# 3. Launcher installed as a symlink back into this skill.
if [[ -L "$LAUNCHER_DST" ]] \
   && [[ "$(readlink -f "$LAUNCHER_DST")" == "$(readlink -f "${SKILL_DIR}/scripts/hshell")" ]]; then
    log_ok "launcher installed: $LAUNCHER_DST"
else
    log_fail "launcher not installed or points elsewhere — run scripts/install.sh"
    fail=1
fi

# 4. home-template looks right.
for f in CLAUDE.md settings.json; do
    if [[ -f "${SKILL_DIR}/home-template/${f}" ]]; then
        log_ok "home-template/${f} present"
    else
        log_fail "home-template/${f} missing"
        fail=1
    fi
done

# 5. Live container check — every critical tool on PATH.
if image_exists; then
    if docker run --rm "${IMAGE_REF}" bash -c '
        set -e
        for cmd in node python claude git gh jq rg fd bat doppler curl; do
            command -v "$cmd" >/dev/null || { echo "MISSING: $cmd"; exit 1; }
        done' >/dev/null 2>&1; then
        log_ok "all expected tools present in image"
    else
        log_fail "one or more expected tools missing in image; re-run build-image.sh"
        fail=1
    fi
fi

if (( fail == 0 )); then
    log_ok "hshell is healthy"
    exit 0
else
    log_fail "hshell health check failed; see above"
    exit 1
fi
