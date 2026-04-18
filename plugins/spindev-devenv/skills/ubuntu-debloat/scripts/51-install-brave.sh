#!/usr/bin/env bash
# Brave (stable) — first-party apt repo, Chromium-based, ships both amd64
# and arm64. Added 2026-04-17 as the arm64 browser story (Chrome is amd64-only
# until Google's Q2'26 arm64 build lands).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "Brave (stable, from Brave's apt repo)"

require_ubuntu
require_arch amd64 arm64

ARCH=$(dpkg_arch)

apt_add_repo "brave-browser" \
    "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
    "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/brave-browser.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"

apt_install brave-browser

if cmd_exists brave-browser; then
    log_ok "brave: $(brave-browser --version)"
fi
