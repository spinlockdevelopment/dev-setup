# shellcheck shell=bash
# Shared helpers for technical-writer scripts.
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
FULL_REGEN=false
for __arg in "${@:-}"; do
    case "$__arg" in
        --verify) VERIFY_MODE=true ;;
        --full-regen) FULL_REGEN=true ;;
    esac
done
export VERIFY_MODE FULL_REGEN

cmd_exists() { command -v "$1" &>/dev/null; }

# Resolve the repo we're documenting. The skill normally runs from the cwd.
# Caller can override by setting REPO_ROOT before sourcing.
resolve_repo_root() {
    if [[ -n "${REPO_ROOT:-}" ]]; then
        echo "$REPO_ROOT"
        return 0
    fi
    if ! cmd_exists git; then
        log_fail "git not found on PATH"
        return 1
    fi
    if ! git rev-parse --show-toplevel &>/dev/null; then
        log_fail "not inside a git repo (cwd: $PWD)"
        return 1
    fi
    git rev-parse --show-toplevel
}

# Stable per-repo key. Prefer remote.origin.url (survives fresh clones);
# fall back to worktree path for repos with no remote.
repo_key() {
    local root="$1"
    local origin
    origin=$(git -C "$root" config --get remote.origin.url 2>/dev/null || true)
    if [[ -z "$origin" ]]; then
        origin="worktree:$root"
    fi
    if cmd_exists sha256sum; then
        echo -n "$origin" | sha256sum | cut -c1-16
    else
        # Cope with macOS / minimal containers where sha256sum is missing.
        echo -n "$origin" | shasum -a 256 | cut -c1-16
    fi
}

state_dir() {
    local base="${XDG_STATE_HOME:-$HOME/.local/state}"
    echo "$base/technical-writer"
}

state_file() {
    local root="$1"
    local key
    key=$(repo_key "$root")
    echo "$(state_dir)/repos/${key}.json"
}

index_file() {
    echo "$(state_dir)/index.json"
}

iso_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Pretty-print a JSON value if jq is around; otherwise pass through.
maybe_jq() {
    if cmd_exists jq; then
        jq "$@"
    else
        cat
    fi
}

# Fail loudly if a required tool is missing. Writer scripts use this so a
# missing prereq surfaces with a clear message, not a cryptic failure.
require_cmd() {
    local missing=()
    for c in "$@"; do
        cmd_exists "$c" || missing+=("$c")
    done
    if (( ${#missing[@]} > 0 )); then
        log_fail "missing required commands: ${missing[*]}"
        log_info "run scripts/preflight.sh to set up tooling"
        return 1
    fi
}
