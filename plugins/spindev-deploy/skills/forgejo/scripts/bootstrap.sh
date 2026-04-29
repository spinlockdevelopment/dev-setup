#!/usr/bin/env bash
# bootstrap.sh — first-time Forgejo bringup. Idempotent.
#
# Usage:
#   bootstrap.sh <hostname> [install-dir]
#   bootstrap.sh git.lan.example.com
#   bootstrap.sh git.lan.example.com /srv/forgejo
#
# What it does:
#   1. Copies docker-compose.yml + .env.example into <install-dir>/
#   2. Sets FORGEJO_DOMAIN in .env to <hostname>
#   3. docker compose up -d, waits for healthy
#   4. Creates the first admin user (prompts for username + password if
#      not pre-set in env), generates an API token, writes it to
#      ~/.config/forgejo/admin-token
#
# Safe to re-run; existing state is preserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd docker curl

HOSTNAME_ARG="${1:-}"
[[ -n "$HOSTNAME_ARG" ]] || die "usage: bootstrap.sh <hostname> [install-dir]"

INSTALL_DIR="${2:-$(forgejo_dir)}"
CFG_DIR="$(config_dir)"

mkdir -p "$INSTALL_DIR" "$CFG_DIR"
chmod 700 "$CFG_DIR"

if [[ ! -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
  log "copying compose files into ${INSTALL_DIR}"
  cp "${SKILL_DIR}/compose/docker-compose.yml" "${INSTALL_DIR}/docker-compose.yml"
fi

if [[ ! -f "${INSTALL_DIR}/.env" ]]; then
  cp "${SKILL_DIR}/compose/.env.example" "${INSTALL_DIR}/.env"
  log "wrote ${INSTALL_DIR}/.env (edit it to change ports / version)"
fi

# Force the hostname argument into .env (idempotent rewrite).
if grep -q '^FORGEJO_DOMAIN=' "${INSTALL_DIR}/.env"; then
  sed -i.bak "s|^FORGEJO_DOMAIN=.*|FORGEJO_DOMAIN=${HOSTNAME_ARG}|" "${INSTALL_DIR}/.env"
  rm -f "${INSTALL_DIR}/.env.bak"
else
  echo "FORGEJO_DOMAIN=${HOSTNAME_ARG}" >> "${INSTALL_DIR}/.env"
fi

# Read ports back so we can talk to the API after compose up.
WEB_PORT="$(grep '^WEB_PORT=' "${INSTALL_DIR}/.env" | cut -d= -f2)"
WEB_PORT="${WEB_PORT:-3000}"

log "starting forgejo via docker compose"
( cd "$INSTALL_DIR" && docker compose up -d )

log "waiting for forgejo to become healthy (up to 90s)"
deadline=$(( $(date +%s) + 90 ))
while (( $(date +%s) < deadline )); do
  if curl -fsS "http://localhost:${WEB_PORT}/api/healthz" >/dev/null 2>&1; then
    ok "forgejo is healthy on http://localhost:${WEB_PORT}"
    break
  fi
  sleep 3
done

if ! curl -fsS "http://localhost:${WEB_PORT}/api/healthz" >/dev/null 2>&1; then
  die "forgejo did not come up — check 'docker compose logs forgejo'"
fi

# Base URL for API calls. Bootstrap always talks to localhost; the
# stored value uses FORGEJO_DOMAIN so other scripts can run remotely.
BASE_URL="http://${HOSTNAME_ARG}:${WEB_PORT}"
echo "$BASE_URL" > "${CFG_DIR}/base-url"

# Admin user creation. Idempotent — Forgejo errors with "already exists",
# we swallow that.
ADMIN_USER="${FORGEJO_ADMIN_USER:-}"
ADMIN_PASS="${FORGEJO_ADMIN_PASS:-}"
ADMIN_EMAIL="${FORGEJO_ADMIN_EMAIL:-admin@${HOSTNAME_ARG}}"

if [[ -z "$ADMIN_USER" ]]; then
  read -rp "admin username: " ADMIN_USER
fi
if [[ -z "$ADMIN_PASS" ]]; then
  read -rsp "admin password (>=12 chars): " ADMIN_PASS
  echo
fi
[[ ${#ADMIN_PASS} -ge 12 ]] || die "password must be >= 12 chars (forgejo policy)"

echo "$ADMIN_USER" > "${CFG_DIR}/admin-user"
chmod 600 "${CFG_DIR}/admin-user"

log "creating admin user '${ADMIN_USER}' (skipped if exists)"
if docker exec --user 1000:1000 forgejo forgejo admin user create \
    --username "$ADMIN_USER" \
    --password "$ADMIN_PASS" \
    --email "$ADMIN_EMAIL" \
    --admin \
    --must-change-password=false 2>&1 | tee /tmp/forgejo-admin-create.log; then
  ok "admin user ready"
else
  if grep -qiE 'already exists|user.*exists' /tmp/forgejo-admin-create.log; then
    log "admin user '${ADMIN_USER}' already exists — keeping existing"
  else
    die "admin user creation failed (see output above)"
  fi
fi
rm -f /tmp/forgejo-admin-create.log

# Mint an API token. We always generate a fresh one named after today —
# old tokens stay (user can prune via UI).
TOKEN_NAME="bootstrap-$(date +%Y%m%d-%H%M%S)"
log "generating API token '${TOKEN_NAME}'"

TOKEN_JSON="$(curl -sS -u "${ADMIN_USER}:${ADMIN_PASS}" \
  -H 'Content-Type: application/json' \
  -X POST "http://localhost:${WEB_PORT}/api/v1/users/${ADMIN_USER}/tokens" \
  -d "{\"name\":\"${TOKEN_NAME}\",\"scopes\":[\"write:admin\",\"write:repository\",\"write:user\"]}")"

TOKEN="$(echo "$TOKEN_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sha1",""))')"
[[ -n "$TOKEN" ]] || die "failed to parse token from API: ${TOKEN_JSON}"

echo "$TOKEN" > "${CFG_DIR}/admin-token"
chmod 600 "${CFG_DIR}/admin-token"

ok "forgejo is up at ${BASE_URL}"
ok "admin: ${ADMIN_USER}"
ok "token saved to ${CFG_DIR}/admin-token"
ok "ssh clone format: ssh://git@${HOSTNAME_ARG}:$(grep '^SSH_PORT=' "${INSTALL_DIR}/.env" | cut -d= -f2)/<user>/<repo>.git"
echo
log "next steps:"
log "  - mirror a github repo:    scripts/add-mirror.sh https://github.com/<user>/<repo>"
log "  - create on-prem-only repo: scripts/create-repo.sh <name>"
log "  - back up the data dir:    see the restic-backup skill"
