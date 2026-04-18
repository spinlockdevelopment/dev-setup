#!/usr/bin/env bash
# bootstrap-app.sh — create a fly app + persistent volume for an
# always-on bot / agent workload. Idempotent.
#
# Usage: bootstrap-app.sh <app-name> <region> [volume-size-gb]
#   app-name:  lowercase alnum + hyphens, globally unique on fly
#   region:    e.g. iad (Ashburn), sjc (San Jose), fra (Frankfurt)
#   volume:    default 3 GB
#
# After success, prints the next commands (secrets, deploy) with the
# correct app name substituted.

set -euo pipefail

APP="${1:-}"; REGION="${2:-}"; SIZE_GB="${3:-3}"
VOL_NAME="data"

[[ -n "${APP}" && -n "${REGION}" ]] || { echo "usage: $0 <app-name> <region> [size-gb]" >&2; exit 2; }
[[ "${APP}" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]] || { echo "app name must be lowercase alnum + hyphens" >&2; exit 2; }

ok()   { printf '\033[0;32m[fly:%s]\033[0m %s\n' "${APP}" "$*"; }
log()  { printf '\033[0;34m[fly:%s]\033[0m %s\n' "${APP}" "$*"; }
die()  { printf '\033[0;31m[fly:%s]\033[0m %s\n' "${APP}" "$*" >&2; exit 1; }

command -v fly >/dev/null || die "flyctl not installed (run install-flyctl.sh first)"

# Create app if missing.
if fly apps list --json 2>/dev/null | python3 -c "
import json,sys
name=sys.argv[1]
apps=json.load(sys.stdin)
print('exists' if any(a.get('Name')==name for a in apps) else 'missing')" "${APP}" | grep -q exists; then
  log "app already exists — skipping creation"
else
  log "creating app"
  fly apps create "${APP}"
  ok "app created"
fi

# Create volume if missing.
if fly volumes list --app "${APP}" --json 2>/dev/null | python3 -c "
import json,sys
name=sys.argv[1]
vols=json.load(sys.stdin)
print('exists' if any(v.get('name')==name or v.get('Name')==name for v in vols) else 'missing')" "${VOL_NAME}" | grep -q exists; then
  log "volume '${VOL_NAME}' already exists — skipping creation"
else
  log "creating ${SIZE_GB} GB volume '${VOL_NAME}' in ${REGION}"
  fly volumes create "${VOL_NAME}" --app "${APP}" --region "${REGION}" --size "${SIZE_GB}" --yes
  ok "volume created"
fi

ok "bootstrap complete"
cat <<EOF

Next steps (run from the dir with your fly.toml):

  1. Set secrets (replace placeholders):
       fly secrets set --app ${APP} \\
         ANTHROPIC_API_KEY="sk-ant-..." \\
         TELEGRAM_BOT_TOKEN="123:..." \\
         GITHUB_TOKEN="github_pat_..."

  2. Deploy:
       fly deploy --app ${APP} --remote-only

  3. Tail logs:
       fly logs --app ${APP}

EOF
