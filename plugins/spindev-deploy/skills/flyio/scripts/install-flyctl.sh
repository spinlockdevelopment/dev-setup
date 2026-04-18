#!/usr/bin/env bash
# install-flyctl.sh — install flyctl via upstream installer into
# ~/.fly/bin and ensure it's on $PATH. Idempotent.
#
# Usage:
#   install-flyctl.sh           # install if missing; upgrade if old
#   install-flyctl.sh --verify  # print version; exit non-zero if missing

set -euo pipefail

INSTALL_DIR="${HOME}/.fly"
BIN="${INSTALL_DIR}/bin/flyctl"

ok()   { printf '\033[0;32m[flyctl]\033[0m %s\n' "$*"; }
log()  { printf '\033[0;34m[flyctl]\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31m[flyctl]\033[0m %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
  --verify)
    if [[ -x "${BIN}" ]]; then
      ver="$("${BIN}" version 2>/dev/null | head -1)"
      ok "installed: ${ver}"
      exit 0
    fi
    die "flyctl not installed at ${BIN}"
    ;;
  ""|--install) ;;
  *) die "unknown arg: $1 (use --verify or no args)" ;;
esac

if [[ -x "${BIN}" ]]; then
  log "already installed: $("${BIN}" version 2>/dev/null | head -1)"
  log "running upstream installer anyway for upgrade-in-place"
fi

command -v curl >/dev/null || die "curl required"
curl -fsSL https://fly.io/install.sh | sh

# Best-effort PATH line for shells that source ~/.bashrc or ~/.zshrc.
for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
  [[ -f "${rc}" ]] || continue
  if ! grep -Fq 'export FLYCTL_INSTALL' "${rc}"; then
    cat >> "${rc}" <<'EOF'

# flyctl (added by flyio skill)
export FLYCTL_INSTALL="$HOME/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"
EOF
    log "added flyctl to PATH in ${rc}"
  fi
done

if [[ ! -x "${BIN}" ]]; then
  die "installer finished but ${BIN} missing"
fi

ok "installed: $("${BIN}" version 2>/dev/null | head -1)"
ok "ensure \$HOME/.fly/bin is on PATH for this shell, or open a new one"
