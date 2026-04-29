#!/usr/bin/env bash
# verify.sh — read-only health check for the forgejo install.
#
# Checks:
#   - container running
#   - web UI healthy
#   - SSH port reachable
#   - admin token works
#   - mirrors are not stale (warns if last_mirror_at older than 2× interval)
#   - data dir size + free disk

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

EXIT=0

check() {
  local label="$1"; shift
  if "$@"; then
    ok "$label"
  else
    warn "FAIL: $label"
    EXIT=1
  fi
}

# 1. Container.
check "container 'forgejo' running" \
  bash -c "docker ps --filter name=^/forgejo\$ --format '{{.Names}}' | grep -q '^forgejo\$'"

# 2. Healthz.
INSTALL_DIR="$(forgejo_dir)"
WEB_PORT="$(grep '^WEB_PORT=' "${INSTALL_DIR}/.env" 2>/dev/null | cut -d= -f2 || echo 3000)"
WEB_PORT="${WEB_PORT:-3000}"
check "web UI healthy on :${WEB_PORT}" \
  curl -fsS --max-time 5 "http://localhost:${WEB_PORT}/api/healthz"

# 3. SSH.
SSH_PORT="$(grep '^SSH_PORT=' "${INSTALL_DIR}/.env" 2>/dev/null | cut -d= -f2 || echo 2222)"
SSH_PORT="${SSH_PORT:-2222}"
check "ssh port :${SSH_PORT} listening" \
  bash -c "(echo > /dev/tcp/localhost/${SSH_PORT}) >/dev/null 2>&1"

# 4. Admin token works.
if [[ -r "$(config_dir)/admin-token" ]]; then
  if api GET /user >/dev/null 2>&1; then
    ok "admin token valid"
  else
    warn "FAIL: admin token rejected by API"
    EXIT=1
  fi
else
  warn "no admin token at $(config_dir)/admin-token (run bootstrap.sh)"
  EXIT=1
fi

# 5. Mirror staleness.
if [[ $EXIT -eq 0 ]]; then
  ADMIN_USER="$(read_admin_user)"
  REPOS_JSON="$(api GET "/users/${ADMIN_USER}/repos?limit=50")"
  python3 - "$REPOS_JSON" <<'PY'
import json, sys, datetime
data = json.loads(sys.argv[1])
now = datetime.datetime.now(datetime.timezone.utc)
stale = []
ok = []
for r in data:
    if not r.get("mirror"):
        continue
    last = r.get("mirror_updated") or r.get("updated_at")
    interval = r.get("mirror_interval", "6h0m0s")
    # crude duration parse: hours only.
    h = 6
    if interval.endswith("h0m0s"):
        try:
            h = int(interval.split("h")[0])
        except Exception:
            h = 6
    elif "h" in interval:
        try:
            h = int(interval.split("h")[0])
        except Exception:
            h = 6
    try:
        t = datetime.datetime.fromisoformat(last.replace("Z","+00:00"))
        age = (now - t).total_seconds() / 3600
        if age > 2 * h:
            stale.append((r["full_name"], f"{age:.1f}h ago, interval {h}h"))
        else:
            ok.append((r["full_name"], f"{age:.1f}h ago"))
    except Exception:
        stale.append((r["full_name"], "unparseable timestamp"))
for n, s in ok:
    print(f"  mirror ok: {n} ({s})")
for n, s in stale:
    print(f"  STALE mirror: {n} ({s})")
sys.exit(1 if stale else 0)
PY
  if [[ $? -ne 0 ]]; then EXIT=1; fi
fi

# 6. Data dir + disk.
if [[ -d "${INSTALL_DIR}/data/forgejo" ]]; then
  SZ="$(du -sh "${INSTALL_DIR}/data/forgejo" 2>/dev/null | cut -f1)"
  FREE="$(df -h "${INSTALL_DIR}/data/forgejo" | awk 'NR==2 {print $4}')"
  log "data dir: ${SZ} used, ${FREE} free on volume"
fi

exit $EXIT
