#!/usr/bin/env bash
# Junction a dev-setup-owned skill into the user's ~/.claude/skills/ tree.
# Usage: install-dep-skill.sh <skill-name>
# Idempotent — no-op if the junction already points at the right source.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

if [[ $# -ne 1 ]]; then
  log_err "usage: $(basename "$0") <skill-name>"
  exit 2
fi

skill="$1"
# Source lives at ../../<skill> relative to this script (dev-setup/.claude/skills/<skill>).
source_dir="$(cd "$SCRIPT_DIR/../.." && pwd)/$skill"
link_dir="$HOME/.claude/skills/$skill"

if [[ ! -d "$source_dir" ]]; then
  log_err "source skill does not exist: $source_dir"
  exit 1
fi

ensure_junction "$source_dir" "$link_dir"
