#!/usr/bin/env bash
# Claude Code statusLine helper (bash wrapper).
#
# Locates a Python 3 interpreter and runs statusline.py, which does the
# actual JSON parsing + formatting. Keeping the Python in a sibling
# file (rather than a heredoc) matters because Claude Code pipes the
# statusLine JSON payload on stdin — `python - <<HEREDOC` would
# consume stdin for the script body and drop the payload.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PY_SCRIPT="$SCRIPT_DIR/statusline.py"

PY=""
for c in python3 python py; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done

if [ -z "$PY" ] || [ ! -f "$PY_SCRIPT" ]; then
    # Degrade gracefully — empty status line is better than a crash.
    exit 0
fi

exec "$PY" "$PY_SCRIPT"
