#!/usr/bin/env bash
# Preflight: ensure git + mkdocs + mkdocs-material are available.
# Installs via pipx when missing. Never sudos directly — prints the apt
# command for the operator to run with the bang-prefix and bails.
#
# Usage:
#   ./preflight.sh            # install missing tools via pipx if possible
#   ./preflight.sh --verify   # report status only, install nothing

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

log_step "preflight"

# git
if cmd_exists git; then
    log_ok "git available ($(git --version))"
else
    log_fail "git not found on PATH"
    log_info "install via: ! sudo apt install -y git"
    exit 1
fi

# mkdocs
if cmd_exists mkdocs; then
    log_ok "mkdocs available ($(mkdocs --version 2>/dev/null | head -n1))"
    MKDOCS_PRESENT=true
else
    log_skip "mkdocs not on PATH"
    MKDOCS_PRESENT=false
fi

# pipx — needed only when mkdocs is missing
if cmd_exists pipx; then
    log_ok "pipx available ($(pipx --version 2>/dev/null))"
    PIPX_PRESENT=true
else
    log_skip "pipx not on PATH"
    PIPX_PRESENT=false
fi

if $MKDOCS_PRESENT; then
    # Even if mkdocs is present, confirm the material theme imports.
    if mkdocs --help 2>/dev/null | grep -q '.'; then
        if python3 -c "import material" 2>/dev/null \
           || python3 -c "from material import __version__" 2>/dev/null \
           || mkdocs build --help 2>&1 | grep -qi material; then
            log_ok "mkdocs-material likely present (passive check)"
        else
            log_info "mkdocs-material may be missing; first 'mkdocs build' will surface it"
        fi
    fi
    exit 0
fi

if $VERIFY_MODE; then
    log_fail "mkdocs missing (verify mode — not installing)"
    exit 1
fi

if ! $PIPX_PRESENT; then
    log_fail "mkdocs missing and pipx is not installed"
    cat >&2 <<'EOF'

Run this in your shell to install pipx, then re-run preflight.sh:

  ! sudo apt install -y pipx && pipx ensurepath

After `pipx ensurepath`, open a new shell so ~/.local/bin is on PATH.
EOF
    exit 1
fi

log_info "installing mkdocs + mkdocs-material via pipx"
pipx install mkdocs
pipx inject mkdocs mkdocs-material mkdocs-awesome-pages-plugin

if cmd_exists mkdocs; then
    log_ok "mkdocs installed ($(mkdocs --version 2>/dev/null | head -n1))"
else
    log_fail "mkdocs install reported success but command is not on PATH"
    log_info "you may need to open a new shell so pipx ensurepath takes effect"
    exit 1
fi
