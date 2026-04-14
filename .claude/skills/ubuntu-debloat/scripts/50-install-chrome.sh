#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "Google Chrome (stable, from Google's apt repo)"

require_ubuntu

apt_add_repo "google-chrome" \
    "https://dl.google.com/linux/linux_signing_key.pub" \
    "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main"

apt_install google-chrome-stable

if cmd_exists google-chrome-stable; then
    log_ok "chrome: $(google-chrome-stable --version)"
fi
