#!/usr/bin/env bash
# add-source.sh — append a directory to the backup sources list.
#
# Usage:
#   add-source.sh <absolute-path> [tag]
#   add-source.sh /srv/forgejo/data forgejo
#   add-source.sh /home/me/projects projects

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

PATH_ARG="${1:-}"
TAG="${2:-default}"

[[ -n "$PATH_ARG" ]] || die "usage: add-source.sh <absolute-path> [tag]"
[[ "${PATH_ARG:0:1}" == "/" ]] || die "path must be absolute: ${PATH_ARG}"

ensure_config_dir
SOURCES="$(config_dir)/sources.list"
touch "$SOURCES"
chmod 600 "$SOURCES"

if ! [[ -d "$PATH_ARG" ]]; then
  warn "path does not exist yet: ${PATH_ARG}"
  warn "(adding anyway — if it never appears, the run will warn)"
fi

# Skip exact-duplicate path entries.
if awk -v p="$PATH_ARG" '$1 == p {found=1} END {exit !found}' "$SOURCES"; then
  log "${PATH_ARG} already in sources list — leaving as-is"
  exit 0
fi

printf '%s\t%s\n' "$PATH_ARG" "$TAG" >> "$SOURCES"
ok "added: ${PATH_ARG} (tag: ${TAG})"
ok "current sources:"
grep -v '^#' "$SOURCES" | grep -v '^[[:space:]]*$' | awk '{print "    " $0}'
