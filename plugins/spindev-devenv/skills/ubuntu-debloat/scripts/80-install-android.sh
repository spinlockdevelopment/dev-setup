#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "Android dev tools (JDK + Android Studio + platform-tools)"

require_ubuntu

# --- JDK (Temurin LTS) ------------------------------------------------------
# Pinned to the current LTS. If check-versions.sh reports a newer LTS,
# bump the `JDK_VERSION` number here and re-run.
# bumped JDK 17 → 21 on 2025-10-01 (Temurin 21 is current LTS)
# bumped JDK 21 → 25 on 2026-04-13 (Temurin 25 is new LTS per check-versions.sh)
JDK_VERSION=25
JDK_PKG="temurin-${JDK_VERSION}-jdk"

apt_add_repo "adoptium" \
    "https://packages.adoptium.net/artifactory/api/gpg/key/public" \
    "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main"

apt_install "$JDK_PKG"

# --- Android platform-tools (adb, fastboot) via Ubuntu package --------------
# renamed 2026-04-17: Ubuntu 24.04+ ships these as `adb` and `fastboot`
# (same-name packages); the old `android-tools-*` meta-packages no longer exist.
apt_install adb fastboot

# --- Android Studio (tarball to /opt) ---------------------------------------
# Upstream download page: https://developer.android.com/studio
# Pinned version string — update when check-versions.sh reports drift.
# Format: "YYYY.N.P.BUILD" ; example "2025.3.3.7"
# bumped Android Studio -> 2024.2.1.12 on 2025-01-15
# bumped Android Studio 2024.2.1.12 -> 2025.3.3.7 on 2026-04-13
# Google switched tarball filenames to codenames (e.g. "panda3-patch1") that
# change per release, so we scrape the URL from the download page rather than
# constructing it from STUDIO_VERSION.
STUDIO_VERSION="2025.3.3.7"
STUDIO_DIR="/opt/android-studio"
STUDIO_BIN="${STUDIO_DIR}/bin/studio.sh"

if [[ "$(dpkg_arch)" != "amd64" ]]; then
    # Google does not publish a Linux arm64 Android Studio tarball (only x86_64).
    # developer.android.com/studio lists exactly one tarball, the linux x86_64 build.
    # corrected 2026-04-17 — earlier commit wrongly assumed an arm64 tarball existed
    log_skip "Android Studio skipped on $(dpkg_arch) — Google ships only x86_64 Linux"
elif [[ -x "$STUDIO_BIN" ]]; then
    log_skip "Android Studio already installed at $STUDIO_DIR"
else
    if $VERIFY_MODE; then
        log_fail "Android Studio not installed"
    else
        require_sudo
        log_info "locating Android Studio $STUDIO_VERSION tarball URL"
        STUDIO_URL=$(curl -fsSL https://developer.android.com/studio 2>/dev/null \
            | grep -oE "https://[^\"]+/android/studio/ide-zips/${STUDIO_VERSION}/android-studio-[^\"]+-linux\.tar\.gz" \
            | head -1)
        if [[ -z "$STUDIO_URL" ]]; then
            log_fail "no Linux tarball URL for $STUDIO_VERSION on developer.android.com/studio — bump STUDIO_VERSION and re-run"
            exit 1
        fi
        STUDIO_TARBALL=$(basename "$STUDIO_URL")
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        log_info "downloading $STUDIO_TARBALL"
        curl -fsSL -o "$tmp/$STUDIO_TARBALL" "$STUDIO_URL"
        log_info "extracting to $STUDIO_DIR"
        sudo rm -rf "$STUDIO_DIR"
        sudo tar -xzf "$tmp/$STUDIO_TARBALL" -C /opt
        log_ok "Android Studio installed at $STUDIO_DIR"

        # Desktop launcher
        sudo tee /usr/share/applications/android-studio.desktop >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Icon=${STUDIO_DIR}/bin/studio.png
Exec="${STUDIO_BIN}" %f
Comment=Android Studio IDE
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-studio
StartupNotify=true
EOF

        # Symlink launcher onto PATH
        sudo ln -sf "$STUDIO_BIN" /usr/local/bin/studio
        log_ok "Android Studio desktop entry + /usr/local/bin/studio symlink"
    fi
fi

# --- Dependencies for running emulators on x86_64 ---------------------------
# KVM for hardware accel; adbkeys perms handled by Android Studio on first run.
# Gated on amd64 because `qemu-kvm` is a transitional meta-package that only
# exists on amd64/i386. On arm64 there is no Android Studio (Google ships
# x86_64 Linux only), so the emulator toolchain is moot anyway. Gated 2026-04-17.
if [[ "$(dpkg_arch)" == "amd64" ]]; then
    apt_install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

    if ! id -nG "$USER" | grep -qw kvm; then
        if $VERIFY_MODE; then
            log_fail "user $USER not in kvm group (needed for emulator accel)"
        else
            require_sudo
            sudo usermod -aG kvm "$USER"
            log_ok "added $USER to kvm group (log out/in for effect)"
        fi
    else
        log_skip "user $USER already in kvm group"
    fi
else
    log_skip "KVM/emulator deps skipped on $(dpkg_arch) (Android Studio is amd64-only)"
fi
