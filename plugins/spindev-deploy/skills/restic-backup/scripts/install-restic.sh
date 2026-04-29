#!/usr/bin/env bash
# install-restic.sh — install pinned restic on the source box.
# Idempotent. --verify to check version without installing.
#
# pinned 2026-04-29 — restic 0.18.1
# https://github.com/restic/restic/releases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

RESTIC_VERSION="0.18.1"
INSTALL_PATH="/usr/local/bin/restic"

case "${1:-}" in
  --verify)
    if command -v restic >/dev/null; then
      ver="$(restic version 2>/dev/null | head -1 || true)"
      ok "installed: ${ver}"
      if [[ "$ver" != *"$RESTIC_VERSION"* ]]; then
        warn "version drift — installed ${ver}, pinned ${RESTIC_VERSION}"
        warn "rerun without --verify to reinstall"
      fi
      exit 0
    fi
    die "restic not on PATH"
    ;;
  ""|--install) ;;
  *) die "unknown arg: $1 (use --verify or no args)" ;;
esac

# Detect arch.
case "$(uname -m)" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l)  ARCH="arm" ;;
  *) die "unsupported arch: $(uname -m)" ;;
esac

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
  linux|darwin|freebsd) ;;
  *) die "unsupported OS: $OS" ;;
esac

# Skip if already at the pinned version.
if command -v restic >/dev/null; then
  cur="$(restic version 2>/dev/null | awk '{print $2}')"
  if [[ "$cur" == "$RESTIC_VERSION" ]]; then
    ok "already at pinned version ${RESTIC_VERSION}"
    exit 0
  fi
  log "installed ${cur} — upgrading to ${RESTIC_VERSION}"
fi

require_cmd curl bzip2

URL="https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_${OS}_${ARCH}.bz2"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log "downloading restic ${RESTIC_VERSION} (${OS}/${ARCH})"
curl -fsSL "$URL" -o "$TMP/restic.bz2"
bzip2 -d "$TMP/restic.bz2"
chmod +x "$TMP/restic"

if [[ -w "$(dirname "$INSTALL_PATH")" ]]; then
  mv "$TMP/restic" "$INSTALL_PATH"
  ok "installed to ${INSTALL_PATH}"
else
  warn "cannot write to $(dirname "$INSTALL_PATH") — needs sudo"
  warn "run as root: sudo install -m 0755 $TMP/restic ${INSTALL_PATH}"
  warn "(re-run this script with sudo, or write a wrapper script and"
  warn " have the user invoke it via '! sudo install-restic.sh')"
  exit 1
fi

ok "installed: $(restic version 2>/dev/null | head -1)"
