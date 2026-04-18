#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "Docker CE (from docker.com, not Ubuntu's docker.io)"

require_ubuntu

# Make sure the old Ubuntu-shipped docker packages aren't installed alongside
apt_purge docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc

CODENAME=$(lsb_release -cs)

apt_add_repo "docker" \
    "https://download.docker.com/linux/ubuntu/gpg" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable"

apt_install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Add current user to docker group (takes effect on next login)
if id -nG "$USER" | grep -qw docker; then
    log_skip "user $USER already in docker group"
else
    if $VERIFY_MODE; then
        log_fail "user $USER not in docker group"
    else
        require_sudo
        sudo usermod -aG docker "$USER"
        log_ok "added $USER to docker group (log out/in for effect)"
    fi
fi

# Enable and start the daemon
if $VERIFY_MODE; then
    systemctl is-enabled docker &>/dev/null && log_ok "docker service enabled" || log_fail "docker service not enabled"
    systemctl is-active  docker &>/dev/null && log_ok "docker service active"   || log_fail "docker service not active"
else
    require_sudo
    sudo systemctl enable --now docker
    log_ok "docker service enabled and running"
fi
