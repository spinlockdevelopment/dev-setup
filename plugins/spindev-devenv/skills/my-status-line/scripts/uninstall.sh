#!/usr/bin/env bash
# Remove the my-status-line helper and unset statusLine in
# ~/.claude/settings.json. Idempotent.

set -euo pipefail

DEST="$HOME/.claude/statusline.sh"
DEST_PY="$HOME/.claude/statusline.py"
SETTINGS="$HOME/.claude/settings.json"

PY=""
for c in python3 python py; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || { echo "my-status-line: python required" >&2; exit 1; }

if [ -f "$DEST" ]; then
    rm -f "$DEST"
    echo "my-status-line: removed $DEST"
fi

if [ -f "$DEST_PY" ]; then
    rm -f "$DEST_PY"
    echo "my-status-line: removed $DEST_PY"
fi

if [ -f "$SETTINGS" ]; then
    "$PY" - "$SETTINGS" <<'PYEOF'
import json, os, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(0)
if isinstance(data, dict) and "statusLine" in data:
    data.pop("statusLine", None)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    print(f"my-status-line: cleared statusLine in {path}")
PYEOF
fi

echo "my-status-line: uninstalled. Restart Claude Code to pick up the change."
