#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "build ${IMAGE_REF}"

require_docker || exit 1

SKILL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1-}" == "--verify" ]]; then
    if image_exists; then
        log_ok "image present: ${IMAGE_REF} ($(docker image inspect -f '{{.Id}}' "$IMAGE_REF"))"
        exit 0
    else
        log_fail "image not built: ${IMAGE_REF}"
        exit 1
    fi
fi

FORCE=false
[[ "${1-}" == "--force" ]] && FORCE=true

if image_exists && ! $FORCE; then
    log_skip "${IMAGE_REF} already built (use --force to rebuild)"
    exit 0
fi

log_info "building (this takes a few minutes on first run)"
docker build --tag "$IMAGE_REF" "$SKILL_DIR"
log_ok "built ${IMAGE_REF}"
