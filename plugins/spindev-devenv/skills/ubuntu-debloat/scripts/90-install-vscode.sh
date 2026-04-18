#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "VS Code (stable, from Microsoft's apt repo)"

require_ubuntu

apt_add_repo "vscode" \
    "https://packages.microsoft.com/keys/microsoft.asc" \
    "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main"

apt_install code

if cmd_exists code; then
    log_ok "VS Code: $(code --version | head -1)"
fi
