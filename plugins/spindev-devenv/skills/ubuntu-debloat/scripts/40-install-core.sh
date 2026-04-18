#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "Core dev tooling + CLI utilities"

require_ubuntu

CORE=(
    build-essential
    pkg-config
    ca-certificates
    curl
    wget
    git
    gnupg
    lsb-release
    software-properties-common
    apt-transport-https
    unzip
    zip
    xz-utils
    file
    ufw
)

CLI=(
    ripgrep
    fd-find
    bat
    fzf
    jq
    tmux
    htop
    btop
    tree
    ncdu
    zsh
    wl-clipboard
    xclip
)

apt_install "${CORE[@]}"
apt_install "${CLI[@]}"

# Ubuntu ships fd-find/bat under awkward binary names (fdfind, batcat) to avoid
# collisions with unrelated legacy packages. Symlink them to their upstream names
# under /usr/local/bin so `fd`/`bat` Just Work.
# added 2026-04-17
for pair in "fd:fdfind" "bat:batcat"; do
    want=${pair%%:*} have=${pair##*:}
    src=$(command -v "$have" 2>/dev/null || true)
    if [[ -z "$src" ]]; then
        log_skip "$have not present yet — skipping /usr/local/bin/$want symlink"
        continue
    fi
    dest=/usr/local/bin/$want
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_skip "$dest already points at $src"
    elif $VERIFY_MODE; then
        [[ -e "$dest" ]] && log_ok "$dest present" || log_fail "$dest symlink missing"
    else
        require_sudo
        sudo ln -sf "$src" "$dest"
        log_ok "symlinked $dest -> $src"
    fi
done

# GitHub CLI — upstream repo, not Ubuntu's stale one
apt_add_repo "github-cli" \
    "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/github-cli.gpg] https://cli.github.com/packages stable main"
apt_install gh

# Enable ufw with sane defaults (deny incoming, allow outgoing).
# Verify path uses `systemctl is-active` (no sudo needed) instead of
# `sudo ufw status`, which false-failed in --verify when sudo can't prompt.
# fixed 2026-04-17
if $VERIFY_MODE; then
    if systemctl is-active --quiet ufw; then
        log_ok "ufw active"
    else
        log_fail "ufw not active"
    fi
else
    require_sudo
    if ! sudo ufw status | grep -q "Status: active"; then
        log_info "enabling ufw (deny in, allow out)"
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
        log_ok "ufw enabled"
    else
        log_skip "ufw already active"
    fi
fi
