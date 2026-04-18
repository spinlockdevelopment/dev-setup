# shellcheck shell=bash
# Shared helpers for hardened-shell scripts.
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

IMAGE_NAME="hshell"
IMAGE_TAG="latest"
IMAGE_REF="${IMAGE_NAME}:${IMAGE_TAG}"

require_docker() {
    if ! command -v docker &>/dev/null; then
        log_fail "docker not installed; install Docker CE first (see ubuntu-debloat skill)"
        return 1
    fi
    if ! docker info &>/dev/null; then
        log_fail "docker daemon not reachable; is the service running and your user in the docker group?"
        return 1
    fi
}

image_exists() {
    docker image inspect "$IMAGE_REF" &>/dev/null
}
