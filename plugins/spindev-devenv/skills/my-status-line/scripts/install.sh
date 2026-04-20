#!/usr/bin/env bash
# Install (or verify) the my-status-line helper.
#
# Copies statusline.sh to ~/.claude/statusline.sh and merges
# `statusLine: { type: "command", command: "bash <path>" }` into
# ~/.claude/settings.json. Idempotent.
#
# Usage:
#   install.sh              # install / update
#   install.sh --verify     # read-only check, exit non-zero if broken

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC_SH="$SCRIPT_DIR/statusline.sh"
SRC_PY="$SCRIPT_DIR/statusline.py"

DEST_DIR="$HOME/.claude"
DEST="$DEST_DIR/statusline.sh"
DEST_PY="$DEST_DIR/statusline.py"
SETTINGS="$DEST_DIR/settings.json"
EXPECTED_CMD="bash $DEST"

verify=0
[ "${1:-}" = "--verify" ] && verify=1

fail() { echo "my-status-line: $*" >&2; exit 1; }

PY=""
for c in python3 python py; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || fail "python not found on PATH (required for JSON handling)"

read_cmd() {
    "$PY" - "$SETTINGS" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
    print((data.get("statusLine") or {}).get("command") or "")
except Exception:
    print("")
PYEOF
}

write_cmd() {
    "$PY" - "$SETTINGS" "$EXPECTED_CMD" <<'PYEOF'
import json, os, sys
path, cmd = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except FileNotFoundError:
    data = {}
except Exception:
    # Corrupt settings: bail rather than overwrite.
    sys.stderr.write("my-status-line: settings.json is not valid JSON; refusing to overwrite\n")
    sys.exit(1)
data["statusLine"] = {"type": "command", "command": cmd}
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
PYEOF
}

clear_cmd() {
    "$PY" - "$SETTINGS" <<'PYEOF'
import json, os, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(0)
if isinstance(data, dict):
    data.pop("statusLine", None)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
PYEOF
}

if [ "$verify" = 1 ]; then
    [ -f "$DEST" ]     || fail "missing helper at $DEST"
    [ -x "$DEST" ]     || fail "helper at $DEST is not executable"
    [ -f "$DEST_PY" ]  || fail "missing python helper at $DEST_PY"
    [ -f "$SETTINGS" ] || fail "missing $SETTINGS"
    actual=$(read_cmd)
    [ "$actual" = "$EXPECTED_CMD" ] \
        || fail "statusLine.command in $SETTINGS is '$actual', expected '$EXPECTED_CMD'"
    echo "my-status-line: OK"
    exit 0
fi

[ -f "$SRC_SH" ] || fail "source not found at $SRC_SH"
[ -f "$SRC_PY" ] || fail "source not found at $SRC_PY"

mkdir -p "$DEST_DIR"
cp "$SRC_SH" "$DEST"
cp "$SRC_PY" "$DEST_PY"
chmod +x "$DEST"

if [ ! -f "$SETTINGS" ]; then
    printf '%s\n' '{}' > "$SETTINGS"
fi

write_cmd

echo "my-status-line: installed"
echo "  helper:   $DEST"
echo "  helper:   $DEST_PY"
echo "  settings: $SETTINGS"
echo "Start a new Claude Code session to see the new status line."

# Export for uninstall.sh to reuse.
export -f clear_cmd >/dev/null 2>&1 || true
