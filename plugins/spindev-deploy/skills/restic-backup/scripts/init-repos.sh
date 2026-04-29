#!/usr/bin/env bash
# init-repos.sh — interactive bringup of the NAS + R2 restic repos.
# Idempotent: re-running against an already-initialized repo is a
# no-op and reports "repo already exists".
#
# Prerequisites:
#   - restic installed on this box (run install-restic.sh first)
#   - rest-server running on the NAS (run install-rest-server.sh on
#     the NAS first; you'll need the rest-server username + password)
#   - Cloudflare R2 bucket created with a write-only-scoped API token
#     (see systemd/r2.env.example for the dashboard steps)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd restic curl

CFG="$(config_dir)"
ensure_config_dir

# ─── Restic password ────────────────────────────────────────────────
PWFILE="${CFG}/password"
if [[ ! -s "$PWFILE" ]]; then
  log "generating a 32-char random restic password"
  if command -v openssl >/dev/null; then
    openssl rand -base64 32 | tr -d '=+/' | cut -c1-32 > "$PWFILE"
  else
    head -c 24 /dev/urandom | base64 | tr -d '=+/' | cut -c1-32 > "$PWFILE"
  fi
  chmod 600 "$PWFILE"
  ok "wrote password to ${PWFILE}"
  warn "BACK THIS UP NOW. Print it. Lose this file = lose the backup."
  warn "Password: $(cat "$PWFILE")"
  read -rp "Press enter once you've copied/printed the password... "
fi
export RESTIC_PASSWORD_FILE="$PWFILE"

# ─── NAS env ────────────────────────────────────────────────────────
NAS_ENV="${CFG}/nas.env"
if [[ ! -f "$NAS_ENV" ]]; then
  echo
  log "NAS rest-server config"
  read -rp "  NAS hostname (e.g. nas.lan): " NAS_HOST
  read -rp "  NAS rest-server port [8000]: " NAS_PORT
  NAS_PORT="${NAS_PORT:-8000}"
  read -rp "  rest-server username: " NAS_USER
  read -rsp "  rest-server password: " NAS_PASS
  echo
  cat > "$NAS_ENV" <<EOF
# Auto-written by init-repos.sh. Sourced by the systemd unit.
NAS_REPO_URL="rest:http://${NAS_USER}:${NAS_PASS}@${NAS_HOST}:${NAS_PORT}/"
RESTIC_PASSWORD_FILE="${PWFILE}"
EOF
  chmod 600 "$NAS_ENV"
  ok "wrote ${NAS_ENV}"
fi

# ─── R2 env ─────────────────────────────────────────────────────────
R2_ENV="${CFG}/r2.env"
if [[ ! -f "$R2_ENV" ]]; then
  echo
  log "Cloudflare R2 config"
  cat <<'EOF'

  Before answering: in the Cloudflare dashboard, create an R2 bucket
  and a token scoped to it.

    R2 → Manage R2 API Tokens → Create API token
      Permissions:    Object Read & Write
      Specify bucket: <bucket name>          (single bucket)
      TTL:            forever                (rotate annually)

  Then edit the token policy to remove s3:DeleteObject and
  s3:DeleteObjectVersion — restic only needs PutObject, GetObject,
  ListBucket. With those removed, leaked source-box creds cannot
  destroy R2 snapshots.

  Optional: enable R2 object lock on the bucket for compliance-mode WORM.

EOF
  read -rp "  Cloudflare account ID: " R2_ACCT
  read -rp "  R2 bucket name: " R2_BUCK
  read -rp "  R2 access key ID: " R2_KEY
  read -rsp "  R2 secret access key: " R2_SEC
  echo
  cp "${SKILL_DIR}/systemd/r2.env.example" "$R2_ENV"
  sed -i.bak \
    -e "s|<r2-access-key-id>|${R2_KEY}|" \
    -e "s|<r2-secret-access-key>|${R2_SEC}|" \
    -e "s|<your-cloudflare-account-id>|${R2_ACCT}|" \
    -e "s|<your-restic-bucket>|${R2_BUCK}|" \
    "$R2_ENV"
  rm -f "${R2_ENV}.bak"
  chmod 600 "$R2_ENV"
  ok "wrote ${R2_ENV}"
fi

# ─── Healthchecks.io URL ────────────────────────────────────────────
HC_ENV="${CFG}/healthcheck.env"
if [[ ! -f "$HC_ENV" ]]; then
  echo
  log "Healthchecks.io ping URL (optional but strongly recommended)"
  log "Sign up at https://healthchecks.io and create a check named e.g. 'restic-backup'."
  log "Set its schedule to match your timer (default: daily). Paste its URL here."
  log "Leave blank to skip; you can edit ${HC_ENV} later."
  read -rp "  Healthchecks ping URL (blank to skip): " HC_URL
  cat > "$HC_ENV" <<EOF
# Auto-written by init-repos.sh.
HEALTHCHECK_URL="${HC_URL}"
EOF
  chmod 600 "$HC_ENV"
fi

# ─── Sources list ───────────────────────────────────────────────────
SOURCES="${CFG}/sources.list"
if [[ ! -f "$SOURCES" ]]; then
  cat > "$SOURCES" <<'EOF'
# One line per backup source: <absolute-path>  <tag>
# Example:
# /srv/forgejo/data    forgejo
# /home/me/projects    projects
EOF
  chmod 600 "$SOURCES"
  ok "wrote ${SOURCES} (add sources with scripts/add-source.sh)"
fi

# ─── restic init ────────────────────────────────────────────────────
log "initializing NAS repo (no-op if already initialized)"
if restic_nas snapshots >/dev/null 2>&1; then
  ok "NAS repo already initialized"
else
  if restic_nas init; then
    ok "NAS repo initialized"
  else
    die "NAS repo init failed — check NAS_REPO_URL in ${NAS_ENV} and rest-server logs on NAS"
  fi
fi

log "initializing R2 repo (no-op if already initialized)"
if restic_r2 snapshots >/dev/null 2>&1; then
  ok "R2 repo already initialized"
else
  if restic_r2 init; then
    ok "R2 repo initialized"
  else
    die "R2 repo init failed — check creds in ${R2_ENV} and bucket exists"
  fi
fi

ok "ready. add sources with scripts/add-source.sh, then install-systemd-units.sh"
