#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "Remove snapd completely"

require_ubuntu

if ! pkg_installed snapd; then
    log_skip "snapd already absent"
    # Still make sure the pinning file is in place so snapd doesn't sneak back.
    if [[ ! -f /etc/apt/preferences.d/nosnap.pref ]]; then
        if ! $VERIFY_MODE; then
            require_sudo
            sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null <<'EOF'
# Block snapd from being reinstalled as a dependency of Firefox etc.
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
            log_ok "snapd apt pin installed"
        fi
    fi
    exit 0
fi

if $VERIFY_MODE; then
    log_fail "snapd still installed"
    exit 1
fi

require_sudo

# Remove any installed snaps in the correct order (core snaps last).
log_info "removing installed snaps"
installed_snaps=$(snap list 2>/dev/null | awk 'NR>1 {print $1}' || true)

# Remove non-core snaps first
for s in $installed_snaps; do
    case "$s" in
        core*|snapd|bare) continue ;;
        *) log_info "removing snap: $s"; sudo snap remove --purge "$s" || true ;;
    esac
done
# Then core snaps
for s in $installed_snaps; do
    case "$s" in
        core*|snapd|bare) log_info "removing snap: $s"; sudo snap remove --purge "$s" || true ;;
    esac
done

log_info "stopping and disabling snapd services"
sudo systemctl disable --now snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

log_info "purging snapd package"
sudo apt-get purge -y snapd
sudo apt-get autoremove -y --purge

log_info "cleaning up snap directories"
sudo rm -rf /var/cache/snapd /var/lib/snapd /snap
rm -rf "${HOME}/snap"

log_info "installing apt pin to prevent snapd reinstallation"
sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null <<'EOF'
# Block snapd from being reinstalled as a dependency of Firefox etc.
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

log_ok "snapd removed and pinned out"
