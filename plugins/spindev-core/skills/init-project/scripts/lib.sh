# Shared helpers for init-project scripts. Source this, don't execute.
# shellcheck shell=bash

set -euo pipefail

log_info() { printf '\033[0;36m[init-project]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[0;33m[init-project]\033[0m %s\n' "$*" >&2; }
log_ok()   { printf '\033[0;32m[init-project]\033[0m %s\n' "$*"; }
log_err()  { printf '\033[0;31m[init-project]\033[0m %s\n' "$*" >&2; }

# is_windows — true when running under Git Bash / MSYS / Cygwin on Windows.
is_windows() {
  case "${OSTYPE:-}" in
    msys*|cygwin*|win32) return 0 ;;
  esac
  [[ "$(uname -s 2>/dev/null || true)" == MINGW* || "$(uname -s 2>/dev/null || true)" == CYGWIN* ]]
}

# have_gh_auth — exit 0 if `gh auth status` is clean, else 1. Silent.
have_gh_auth() {
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1
}

# to_windows_path <unix-path> — convert a Git Bash path to a Windows path suitable for mklink.
to_windows_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p"
  else
    # Best-effort fallback: assume already Windows-shaped.
    printf '%s' "$p"
  fi
}

# ensure_junction <target-dir> <link-path>
#   Idempotently create a directory junction (Windows) or symlink (Linux/macOS)
#   at <link-path> pointing to <target-dir>. No-op if already correct.
#   Errors if <link-path> exists as a file or as a link pointing elsewhere.
ensure_junction() {
  local target="$1"
  local link="$2"

  if [[ ! -d "$target" ]]; then
    log_err "ensure_junction: target does not exist: $target"
    return 1
  fi

  if [[ -L "$link" ]]; then
    local current
    current="$(readlink "$link")"
    # readlink may return the Windows form on junctions; compare loosely.
    if [[ "$current" == "$target" || "$current" == "$(to_windows_path "$target")" ]]; then
      log_ok "junction already in place: $link"
      return 0
    fi
    log_err "$link already links to $current (expected $target) — refusing to overwrite"
    return 1
  fi

  if [[ -e "$link" ]]; then
    log_err "$link exists and is not a link — refusing to overwrite"
    return 1
  fi

  mkdir -p "$(dirname "$link")"

  if is_windows; then
    local link_win target_win
    link_win="$(to_windows_path "$link")"
    target_win="$(to_windows_path "$target")"
    MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 \
      cmd.exe /c mklink /J "$link_win" "$target_win" >/dev/null
    log_ok "junctioned $link → $target"
  else
    ln -s "$target" "$link"
    log_ok "symlinked $link → $target"
  fi
}
