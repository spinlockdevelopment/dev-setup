#!/usr/bin/env bash
# Verify mode — read-only health check across everything this skill installs.
# This script always runs in verify mode regardless of flags; use individual
# numbered scripts with --verify for per-phase checks.
set -euo pipefail
VERIFY_MODE=true
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
VERIFY_MODE=true
export VERIFY_MODE

fails=0
check() { "$@" || ((fails++)) || true; }

log_step "Verify: Ubuntu dev setup health"

check require_ubuntu

log_step "Bloat removed"
for p in firefox firefox-esr snapd libreoffice-core thunderbird \
         aisleriot gnome-mahjongg gnome-mines gnome-sudoku rhythmbox \
         shotwell cheese transmission-gtk; do
    if pkg_installed "$p"; then
        log_fail "still installed (should be purged): $p"
        fails=$((fails + 1))
    else
        log_ok "absent: $p"
    fi
done

log_step "Core tools present"
for c in git curl wget gpg lsb_release make gcc rg fd bat fzf jq gh tmux htop tree ncdu; do
    check assert_cmd "$c"
done

log_step "Browser + IDEs"
if [[ "$(dpkg_arch)" == "amd64" ]]; then
    check assert_cmd google-chrome-stable "Google Chrome"
else
    log_skip "Google Chrome check — no upstream build for $(dpkg_arch)"
fi
check assert_cmd brave-browser "Brave"
check assert_cmd code "VS Code"

log_step "Container toolchain"
check assert_cmd docker "Docker"
if cmd_exists docker && ! $VERIFY_MODE; then :; fi
if systemctl is-active docker &>/dev/null; then
    log_ok "docker service active"
else
    log_fail "docker service not active"
    fails=$((fails + 1))
fi
id -nG "$USER" | grep -qw docker && log_ok "user in docker group" || { log_fail "user not in docker group"; fails=$((fails + 1)); }

log_step "Language toolchains (mise)"
MISE_BIN="${HOME}/.local/bin/mise"
if [[ -x "$MISE_BIN" ]]; then
    log_ok "mise present: $("$MISE_BIN" --version)"
    for tool in node python go java; do
        if "$MISE_BIN" which "$tool" &>/dev/null; then
            log_ok "mise tool: $tool → $("$MISE_BIN" current "$tool" 2>/dev/null || echo unknown)"
        else
            log_fail "mise tool missing: $tool"
            fails=$((fails + 1))
        fi
    done
else
    log_fail "mise not installed"
    fails=$((fails + 1))
fi

log_step "Android dev"
check assert_cmd adb "adb"
check assert_cmd fastboot "fastboot"
if [[ "$(dpkg_arch)" != "amd64" ]]; then
    log_skip "Android Studio check — Google ships only x86_64 Linux build"
elif [[ -x /opt/android-studio/bin/studio.sh ]]; then
    log_ok "Android Studio installed"
else
    log_fail "Android Studio not installed"
    fails=$((fails + 1))
fi

log_step "System state"
if systemctl is-enabled unattended-upgrades &>/dev/null; then
    log_ok "unattended-upgrades enabled"
else
    log_fail "unattended-upgrades not enabled"
    fails=$((fails + 1))
fi
if systemctl is-active ufw &>/dev/null; then
    log_ok "ufw active"
else
    log_fail "ufw not active"
    fails=$((fails + 1))
fi

updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)
if (( updates > 0 )); then
    log_fail "$updates apt packages upgradable"
    fails=$((fails + 1))
else
    log_ok "apt fully up to date"
fi

echo
if (( fails == 0 )); then
    printf "${C_GRN}verify passed${C_OFF} — system looks healthy\n"
    exit 0
else
    printf "${C_RED}verify failed${C_OFF} — %d issue(s); run run-all.sh (without --verify) to fix\n" "$fails"
    exit 1
fi
