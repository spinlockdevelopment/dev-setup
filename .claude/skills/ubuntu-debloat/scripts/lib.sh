# shellcheck shell=bash
# Shared helpers for ubuntu-debloat scripts.
# Source with: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ -t 1 ]]; then
    C_RED='\033[0;31m'; C_GRN='\033[0;32m'; C_YEL='\033[0;33m'
    C_BLU='\033[0;34m'; C_DIM='\033[2m'; C_OFF='\033[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_DIM=''; C_OFF=''
fi

log_ok()   { printf "${C_GRN}[OK]${C_OFF}   %s\n" "$*"; }
log_skip() { printf "${C_BLU}[SKIP]${C_OFF} %s\n" "$*"; }
log_fail() { printf "${C_RED}[FAIL]${C_OFF} %s\n" "$*" >&2; }
log_info() { printf "${C_YEL}[..]${C_OFF}   %s\n" "$*"; }
log_step() { printf "\n${C_DIM}==>${C_OFF} %s\n" "$*"; }

VERIFY_MODE=false
for __arg in "${@:-}"; do
    [[ "$__arg" == "--verify" ]] && VERIFY_MODE=true
done
export VERIFY_MODE

require_ubuntu() {
    if ! command -v lsb_release &>/dev/null; then
        log_fail "lsb_release not found — is this Ubuntu?"
        exit 1
    fi
    local id ver major
    id=$(lsb_release -si)
    ver=$(lsb_release -sr)
    major=${ver%%.*}
    if [[ "$id" != "Ubuntu" ]]; then
        log_fail "this skill targets Ubuntu; detected: $id"
        exit 1
    fi
    if (( major < 24 )); then
        log_fail "Ubuntu $ver is too old; require 24.04+"
        exit 1
    fi
}

# dpkg architecture ("amd64", "arm64", ...) — normalized, unlike `uname -m`.
dpkg_arch() { dpkg --print-architecture; }

# Skip the calling script cleanly if we're not on one of the listed dpkg archs.
# Usage: require_arch amd64          # only amd64
#        require_arch amd64 arm64    # either
require_arch() {
    local want arch
    arch=$(dpkg_arch)
    for want in "$@"; do
        [[ "$arch" == "$want" ]] && return 0
    done
    log_skip "skipping on $arch (supported: $*)"
    exit 0
}

require_sudo() {
    if [[ $EUID -eq 0 ]]; then
        log_fail "do not run as root; run as your user — sudo will be used where needed"
        exit 1
    fi
    if ! sudo -n true 2>/dev/null; then
        log_info "this step needs sudo; you may be prompted for your password"
        sudo -v || { log_fail "sudo required"; exit 1; }
    fi
}

pkg_installed() { dpkg -s "$1" &>/dev/null; }
cmd_exists()    { command -v "$1" &>/dev/null; }

apt_install() {
    local pkgs=("$@") missing=()
    for p in "${pkgs[@]}"; do pkg_installed "$p" || missing+=("$p"); done
    if (( ${#missing[@]} == 0 )); then
        log_skip "already installed: ${pkgs[*]}"
        return 0
    fi
    if $VERIFY_MODE; then
        log_fail "missing packages: ${missing[*]}"
        return 1
    fi
    require_sudo
    log_info "installing: ${missing[*]}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
    log_ok "installed: ${missing[*]}"
}

apt_purge() {
    local pkgs=("$@") present=()
    for p in "${pkgs[@]}"; do pkg_installed "$p" && present+=("$p"); done
    if (( ${#present[@]} == 0 )); then
        log_skip "already purged: ${pkgs[*]}"
        return 0
    fi
    if $VERIFY_MODE; then
        log_fail "still installed (should be purged): ${present[*]}"
        return 1
    fi
    require_sudo
    log_info "purging: ${present[*]}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y "${present[@]}"
    log_ok "purged: ${present[*]}"
}

# Add a keyring + apt source idempotently.
# args: name keyring_url source_line
apt_add_repo() {
    local name="$1" keyring_url="$2" source_line="$3"
    local keyring="/etc/apt/keyrings/${name}.gpg"
    # one-line "deb [opts] URL suite comp" format belongs in a .list file;
    # .sources files require deb822 multiline format and fail to parse otherwise.
    # fixed on 2026-04-13 after vscode install hit "Malformed stanza" error.
    local source_file="/etc/apt/sources.list.d/${name}.list"

    if [[ -f "$keyring" && -f "$source_file" ]]; then
        log_skip "apt repo already configured: $name"
        return 0
    fi
    if $VERIFY_MODE; then
        log_fail "apt repo not configured: $name"
        return 1
    fi
    require_sudo
    log_info "configuring apt repo: $name"
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "$keyring_url" | sudo gpg --dearmor -o "$keyring"
    sudo chmod a+r "$keyring"
    echo "$source_line" | sudo tee "$source_file" >/dev/null
    sudo apt-get update -qq
    log_ok "apt repo configured: $name"
}

# Asserts in verify mode, otherwise a no-op. Use for "this file should exist".
assert_file() {
    local path="$1" label="${2:-$1}"
    if [[ -e "$path" ]]; then
        log_ok "$label present"
    else
        log_fail "$label missing: $path"
        return 1
    fi
}

assert_cmd() {
    local cmd="$1" label="${2:-$1}"
    if cmd_exists "$cmd"; then
        log_ok "$label available ($(command -v "$cmd"))"
    else
        log_fail "$label not available on PATH"
        return 1
    fi
}
