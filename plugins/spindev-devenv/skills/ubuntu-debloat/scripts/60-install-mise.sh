#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "mise + language toolchains (Python, Node LTS, Go, Java LTS)"

require_ubuntu

# mise installs to ~/.local/bin
MISE_BIN="${HOME}/.local/bin/mise"

if [[ ! -x "$MISE_BIN" ]]; then
    if $VERIFY_MODE; then
        log_fail "mise not installed"
        exit 1
    fi
    log_info "installing mise via official installer"
    curl -fsSL https://mise.run | sh
    log_ok "mise installed at $MISE_BIN"
else
    log_skip "mise already installed: $("$MISE_BIN" --version)"
fi

# Ensure shell activation is in place — bash + zsh
activate_bash='eval "$(~/.local/bin/mise activate bash)"'
activate_zsh='eval "$(~/.local/bin/mise activate zsh)"'

ensure_line() {
    local file="$1" line="$2"
    [[ -f "$file" ]] || return 0
    if ! grep -Fq "$line" "$file"; then
        if $VERIFY_MODE; then
            log_fail "mise activation missing from $file"
            return 1
        fi
        echo "$line" >> "$file"
        log_ok "added mise activation to $file"
    else
        log_skip "mise activation already in $file"
    fi
}

ensure_line "${HOME}/.bashrc" "$activate_bash"
[[ -f "${HOME}/.zshrc" ]] && ensure_line "${HOME}/.zshrc" "$activate_zsh"

# Install language toolchains via mise.
# We target LTS / latest stable — mise resolves these tokens at install time.
TOOLS=(
    "node@lts"
    "python@3"
    "go@latest"
    "java@lts"
)

for tool in "${TOOLS[@]}"; do
    name="${tool%@*}"
    if "$MISE_BIN" which "$name" &>/dev/null; then
        log_skip "mise tool already present: $tool ($("$MISE_BIN" current "$name" 2>/dev/null || echo unknown))"
        continue
    fi
    if $VERIFY_MODE; then
        log_fail "mise tool missing: $tool"
        continue
    fi
    log_info "mise use -g $tool"
    "$MISE_BIN" use -g "$tool"
    log_ok "mise installed: $tool"
done

# uv — fast Python package manager, worth having alongside mise-managed python
if ! cmd_exists uv; then
    if $VERIFY_MODE; then
        log_fail "uv not installed"
    else
        log_info "installing uv"
        curl -fsSL https://astral.sh/uv/install.sh | sh
        log_ok "uv installed"
    fi
else
    log_skip "uv already installed: $(uv --version)"
fi

# pnpm — alternative JS package manager, opt-in but cheap
if ! cmd_exists pnpm; then
    if ! $VERIFY_MODE; then
        log_info "installing pnpm via corepack"
        "$MISE_BIN" exec node@lts -- corepack enable 2>/dev/null || true
        "$MISE_BIN" exec node@lts -- corepack prepare pnpm@latest --activate 2>/dev/null || true
        log_ok "pnpm enabled via corepack"
    fi
else
    log_skip "pnpm already present: $(pnpm --version)"
fi
