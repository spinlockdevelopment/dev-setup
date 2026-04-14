#!/usr/bin/env bash
# Install a narrowly-scoped /etc/sudoers.d/ubuntu-debloat for the duration
# of this run so subsequent phases don't prompt for a password.
#
# Lifecycle: installed here, reverted by run-all.sh's EXIT trap. If you
# invoke this script standalone (not via run-all.sh), the fragment persists
# until manually removed: `sudo rm /etc/sudoers.d/ubuntu-debloat`.
#
# Scope: sudo can't authorize on CWD or parent process, only on user +
# command. These rules allow passwordless apt install/purge, snap removal,
# systemctl enable/disable, ufw configuration, a handful of specific
# /etc/apt file ops, and adding the user to docker/kvm groups. Any process
# running as $USER benefits from these rules — intended for single-user
# dev workstations only.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "sudoers NOPASSWD (ephemeral — reverted on run-all.sh exit)"

require_ubuntu
if [[ $EUID -eq 0 ]]; then
    log_fail "do not run as root"
    exit 1
fi

SUDOERS_FILE="/etc/sudoers.d/ubuntu-debloat"

RENDERED=$(mktemp)
trap 'rm -f "$RENDERED"' EXIT

cat > "$RENDERED" <<EOF
# /etc/sudoers.d/ubuntu-debloat — installed by the ubuntu-debloat skill.
# EPHEMERAL: run-all.sh's EXIT trap removes this file when the run ends.
# Narrowly-scoped NOPASSWD rules for the specific commands the skill runs.
# Any process running as $USER benefits from these rules while present.
# Remove manually with: sudo rm $SUDOERS_FILE

Defaults:$USER env_keep += "DEBIAN_FRONTEND"

Cmnd_Alias UBUNTU_DEBLOAT_APT = \\
    /usr/bin/apt-get update, \\
    /usr/bin/apt-get update -qq, \\
    /usr/bin/apt-get -y upgrade, \\
    /usr/bin/apt-get -y install *, \\
    /usr/bin/apt-get install -y *, \\
    /usr/bin/apt-get -y purge *, \\
    /usr/bin/apt-get purge -y *, \\
    /usr/bin/apt-get -y autoremove, \\
    /usr/bin/apt-get -y autoremove *, \\
    /usr/bin/apt-get autoremove -y *, \\
    /usr/bin/dpkg-reconfigure -f noninteractive unattended-upgrades

Cmnd_Alias UBUNTU_DEBLOAT_SNAP = /usr/bin/snap remove --purge *

Cmnd_Alias UBUNTU_DEBLOAT_SYSTEMCTL = \\
    /usr/bin/systemctl enable --now *, \\
    /usr/bin/systemctl disable --now *

Cmnd_Alias UBUNTU_DEBLOAT_UFW = \\
    /usr/sbin/ufw status, \\
    /usr/sbin/ufw default deny incoming, \\
    /usr/sbin/ufw default allow outgoing, \\
    /usr/sbin/ufw --force enable

Cmnd_Alias UBUNTU_DEBLOAT_APT_CFG = \\
    /usr/bin/install -d -m 0755 /etc/apt/keyrings, \\
    /usr/bin/gpg --dearmor -o /etc/apt/keyrings/*, \\
    /usr/bin/chmod a+r /etc/apt/keyrings/*, \\
    /usr/bin/tee /etc/apt/sources.list.d/*, \\
    /usr/bin/tee /etc/apt/preferences.d/nosnap.pref

Cmnd_Alias UBUNTU_DEBLOAT_FS = \\
    /usr/bin/rm -rf /var/cache/snapd, \\
    /usr/bin/rm -rf /var/lib/snapd, \\
    /usr/bin/rm -rf /snap, \\
    /usr/bin/rm -rf /opt/android-studio, \\
    /usr/bin/tar -xzf /tmp/*/*.tar.gz -C /opt, \\
    /usr/bin/tee /usr/share/applications/android-studio.desktop, \\
    /usr/bin/ln -sf /opt/android-studio/bin/studio.sh /usr/local/bin/studio

Cmnd_Alias UBUNTU_DEBLOAT_USERS = \\
    /usr/sbin/usermod -aG docker *, \\
    /usr/sbin/usermod -aG kvm *

# Self-revert: lets run-all.sh's EXIT trap remove this file without prompt.
Cmnd_Alias UBUNTU_DEBLOAT_REVERT = /usr/bin/rm -f $SUDOERS_FILE

$USER ALL=(root) NOPASSWD: UBUNTU_DEBLOAT_APT, \\
                           UBUNTU_DEBLOAT_SNAP, \\
                           UBUNTU_DEBLOAT_SYSTEMCTL, \\
                           UBUNTU_DEBLOAT_UFW, \\
                           UBUNTU_DEBLOAT_APT_CFG, \\
                           UBUNTU_DEBLOAT_FS, \\
                           UBUNTU_DEBLOAT_USERS, \\
                           UBUNTU_DEBLOAT_REVERT
EOF

if $VERIFY_MODE; then
    log_skip "ephemeral phase — nothing persists across runs to verify"
    exit 0
fi

cat <<BANNER

   Ephemeral sudoers fragment — will be installed for this run only.

   Path:        $SUDOERS_FILE
   Applies to:  user '$USER' only
   Lifecycle:   installed now, removed by run-all.sh on exit
   Manual rm:   sudo rm $SUDOERS_FILE

   Rules being installed:
------------------------------------------------------------
BANNER
cat "$RENDERED"
cat <<'BANNER'
------------------------------------------------------------

BANNER

require_sudo

# Validate BEFORE installing — a bad sudoers.d file disables sudo entirely.
if ! sudo visudo -cf "$RENDERED" >/dev/null; then
    log_fail "generated sudoers fragment failed visudo validation — refusing to install"
    sudo visudo -cf "$RENDERED" || true
    exit 1
fi

sudo install -m 0440 -o root -g root "$RENDERED" "$SUDOERS_FILE"
log_ok "installed $SUDOERS_FILE (reverted on run-all.sh exit)"
