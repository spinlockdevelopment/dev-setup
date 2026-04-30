#!/usr/bin/env bash
# Run mkdocs build. With --verify, runs mkdocs build --strict (read-only-ish:
# still writes site/ but exits non-zero on broken nav, missing pages, etc.).
#
# Usage:
#   ./build-docs.sh
#   ./build-docs.sh --verify

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

require_cmd mkdocs git || exit 1

ROOT="$(resolve_repo_root)" || exit 1
cd "$ROOT"

if [[ ! -f mkdocs.yml ]]; then
    log_fail "mkdocs.yml not found at $ROOT — run scaffold-mkdocs.sh first"
    exit 1
fi

if $VERIFY_MODE; then
    log_step "mkdocs build --strict"
    mkdocs build --strict
else
    log_step "mkdocs build"
    mkdocs build
fi

log_ok "site built at $ROOT/site/"
