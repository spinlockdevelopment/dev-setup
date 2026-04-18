#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "System update + unattended-upgrades"

require_ubuntu

if $VERIFY_MODE; then
    # Report if any upgradable packages remain
    updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)
    if (( updates > 0 )); then
        log_fail "$updates packages upgradable (run without --verify to apply)"
    else
        log_ok "system fully up to date"
    fi
else
    require_sudo
    log_info "apt update"
    sudo apt-get update -qq
    log_info "apt upgrade"
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
    log_info "apt autoremove"
    sudo apt-get -y autoremove --purge
    log_ok "system upgraded"
fi

# Enable unattended-upgrades for security patches
apt_install unattended-upgrades

if $VERIFY_MODE; then
    if systemctl is-enabled unattended-upgrades &>/dev/null; then
        log_ok "unattended-upgrades enabled"
    else
        log_fail "unattended-upgrades not enabled"
    fi
else
    require_sudo
    sudo dpkg-reconfigure -f noninteractive unattended-upgrades
    sudo systemctl enable --now unattended-upgrades
    log_ok "unattended-upgrades enabled"
fi
