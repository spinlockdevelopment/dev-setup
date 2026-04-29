#!/usr/bin/env bash
# install-rest-server.sh — install pinned rest-server on the NAS in
# --append-only mode.
#
# Run this ON THE NAS, not on the source box.
#
# pinned 2026-04-29 — rest-server v0.14.0
# https://github.com/restic/rest-server/releases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

REST_SERVER_VERSION="0.14.0"
INSTALL_PATH="/usr/local/bin/rest-server"
DATA_DIR="${REST_SERVER_DATA:-/srv/restic}"
HTPASSWD_PATH="${REST_SERVER_HTPASSWD:-/etc/rest-server/htpasswd}"
LISTEN="${REST_SERVER_LISTEN:-:8000}"

case "${1:-}" in
  --verify)
    command -v rest-server >/dev/null || die "rest-server not installed"
    ok "installed: $(rest-server --version 2>&1 | head -1)"
    systemctl is-active --quiet rest-server && ok "service active" || warn "service not active"
    exit 0
    ;;
  ""|--install) ;;
  *) die "unknown arg: $1 (use --verify or no args)" ;;
esac

# Arch detection.
case "$(uname -m)" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l)  ARCH="arm" ;;
  *) die "unsupported arch: $(uname -m)" ;;
esac

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
[[ "$OS" == "linux" ]] || die "rest-server systemd path supports linux only — install manually elsewhere"

require_cmd curl tar

if [[ ! -w "$(dirname "$INSTALL_PATH")" ]]; then
  die "needs root — re-run via 'sudo install-rest-server.sh'"
fi

# Download + install binary.
URL="https://github.com/restic/rest-server/releases/download/v${REST_SERVER_VERSION}/rest-server_${REST_SERVER_VERSION}_${OS}_${ARCH}.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log "downloading rest-server ${REST_SERVER_VERSION} (${OS}/${ARCH})"
curl -fsSL "$URL" -o "$TMP/rs.tgz"
tar -C "$TMP" -xzf "$TMP/rs.tgz"
RS_BIN="$(find "$TMP" -name rest-server -type f | head -1)"
[[ -n "$RS_BIN" ]] || die "rest-server binary not found in archive"
install -m 0755 "$RS_BIN" "$INSTALL_PATH"
ok "installed to ${INSTALL_PATH}"

# Data dir + htpasswd dir.
mkdir -p "$DATA_DIR" "$(dirname "$HTPASSWD_PATH")"
chown root:root "$DATA_DIR"
chmod 0700 "$DATA_DIR"

# Create a system user to run rest-server.
if ! id rest-server >/dev/null 2>&1; then
  useradd --system --home-dir "$DATA_DIR" --shell /usr/sbin/nologin rest-server
  chown -R rest-server:rest-server "$DATA_DIR"
  log "created rest-server system user"
fi

# Bootstrap an htpasswd file if missing. Keep --no-auth disabled — we
# want HTTP Basic auth even on LAN, since the source box's NAS creds
# is what enforces append-only at the user level (paired with
# --append-only at the server level).
if [[ ! -f "$HTPASSWD_PATH" ]]; then
  require_cmd htpasswd 2>/dev/null || apt-get install -y apache2-utils >/dev/null 2>&1 || true
  if ! command -v htpasswd >/dev/null; then
    warn "htpasswd not installed — install apache2-utils (debian/ubuntu) or httpd-tools (rhel)"
    warn "then create ${HTPASSWD_PATH} with: htpasswd -B -c ${HTPASSWD_PATH} <username>"
  else
    read -rp "rest-server username for source box: " RS_USER
    htpasswd -B -c "$HTPASSWD_PATH" "$RS_USER"
    chmod 0640 "$HTPASSWD_PATH"
    chown root:rest-server "$HTPASSWD_PATH"
    ok "created ${HTPASSWD_PATH} for user '${RS_USER}'"
  fi
fi

# Drop the systemd unit. Append-only is the critical flag here.
SYSTEMD_DIR="/etc/systemd/system"
SYSTEMD_UNIT_SRC="$(dirname "$SCRIPT_DIR")/systemd/rest-server.service"
SYSTEMD_UNIT_DST="${SYSTEMD_DIR}/rest-server.service"

if [[ -f "$SYSTEMD_UNIT_SRC" ]]; then
  install -m 0644 "$SYSTEMD_UNIT_SRC" "$SYSTEMD_UNIT_DST"
  ok "installed unit at ${SYSTEMD_UNIT_DST}"
else
  warn "unit template missing at ${SYSTEMD_UNIT_SRC} — re-run from skill checkout"
fi

systemctl daemon-reload
systemctl enable --now rest-server.service
sleep 2
if systemctl is-active --quiet rest-server; then
  ok "rest-server active on ${LISTEN} (--append-only, data ${DATA_DIR})"
else
  warn "rest-server failed to start — check 'journalctl -u rest-server'"
fi

cat <<EOF

  Source-box config (paste into ~/.config/restic-backup/nas.env on the source):

    NAS_REPO_URL="rest:http://<RS_USER>:<RS_PASSWORD>@$(hostname -f):${LISTEN#:}/"

  The source-box password is what you set in htpasswd above. The
  server is in --append-only mode, so leaked source-box creds cannot
  delete existing snapshots.

EOF
