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

# GitHub CLI — upstream repo, not Ubuntu's stale one
apt_add_repo "github-cli" \
    "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/github-cli.gpg] https://cli.github.com/packages stable main"
apt_install gh

# Enable ufw with sane defaults (deny incoming, allow outgoing)
if $VERIFY_MODE; then
    if sudo ufw status | grep -q "Status: active"; then
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
