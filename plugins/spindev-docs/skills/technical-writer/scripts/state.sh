#!/usr/bin/env bash
# Per-repo state for the technical-writer.
#
# Subcommands:
#   read                       print the state JSON for the current repo (empty if first run)
#   write <commit> [pages...]  record HEAD + ISO timestamp + page list
#   delta                      print files changed since last_commit, one per line
#   mode                       print: full | incremental | no-op | rebase-fallback | first-run
#   clear                      forget the current repo's state
#   list-repos                 print the index of all documented repos
#
# All subcommands operate on the current repo by default. Override with
# REPO_ROOT=/path env var.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

require_cmd git || exit 1

ROOT="$(resolve_repo_root)" || exit 1
STATE="$(state_file "$ROOT")"
INDEX="$(index_file)"

mkdir -p "$(dirname "$STATE")"

# Use jq for safety. If jq is missing, fall back to writing the JSON by hand.
HAVE_JQ=false
cmd_exists jq && HAVE_JQ=true

read_state() {
    if [[ -f "$STATE" ]]; then
        cat "$STATE"
    else
        echo "{}"
    fi
}

read_field() {
    local field="$1"
    if $HAVE_JQ; then
        read_state | jq -r --arg k "$field" '.[$k] // empty'
    else
        # Best-effort grep of "field": "value" — fine for top-level scalars.
        read_state | grep -oE "\"$field\":[[:space:]]*\"[^\"]*\"" \
            | head -n1 \
            | sed -E 's/.*: *"([^"]*)"/\1/'
    fi
}

write_state() {
    local commit="$1"
    shift
    local -a pages=("$@")
    local key
    key=$(repo_key "$ROOT")
    local origin
    origin=$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null || echo "")
    local branch
    branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    local now
    now=$(iso_now)

    local doc_root="docs"
    local mkdocs_config="mkdocs.yml"
    # Prefer the live mkdocs.yml on disk over any prior state — that's what
    # the scaffold step just wrote, and it's what the next run will read.
    if [[ -f "$ROOT/$mkdocs_config" ]]; then
        local live
        live=$(grep -E '^docs_dir:' "$ROOT/$mkdocs_config" 2>/dev/null \
               | head -n1 \
               | sed -E 's/^docs_dir:[[:space:]]*//; s/[[:space:]]*$//')
        [[ -n "$live" ]] && doc_root="$live"
    fi
    # Fall back to prior state if mkdocs.yml didn't pin docs_dir.
    local existing_doc_root existing_config
    existing_doc_root=$(read_field doc_root)
    existing_config=$(read_field mkdocs_config)
    [[ -z "$doc_root" || "$doc_root" == "docs" ]] && [[ -n "$existing_doc_root" ]] && doc_root="$existing_doc_root"
    [[ -n "$existing_config" ]] && mkdocs_config="$existing_config"

    if $HAVE_JQ; then
        # Build pages array via jq for proper escaping.
        local pages_json
        pages_json=$(printf '%s\n' "${pages[@]}" | jq -R . | jq -s .)
        jq -n \
            --arg schema 1 \
            --arg repo_key "$key" \
            --arg remote_url "$origin" \
            --arg worktree "$ROOT" \
            --arg last_commit "$commit" \
            --arg last_branch "$branch" \
            --arg last_run_iso "$now" \
            --arg doc_root "$doc_root" \
            --arg mkdocs_config "$mkdocs_config" \
            --argjson pages_generated "$pages_json" \
            '{schema:($schema|tonumber), repo_key:$repo_key, remote_url:$remote_url, worktree:$worktree, last_commit:$last_commit, last_branch:$last_branch, last_run_iso:$last_run_iso, doc_root:$doc_root, mkdocs_config:$mkdocs_config, pages_generated:$pages_generated}' \
            > "$STATE"
    else
        # Hand-roll the JSON. Pages are not perfectly escaped here — but page
        # filenames are model-controlled and conform to mkdocs' filename
        # rules, so plain double-quoting is safe enough for the fallback.
        {
            printf '{\n'
            printf '  "schema": 1,\n'
            printf '  "repo_key": "%s",\n' "$key"
            printf '  "remote_url": "%s",\n' "$origin"
            printf '  "worktree": "%s",\n' "$ROOT"
            printf '  "last_commit": "%s",\n' "$commit"
            printf '  "last_branch": "%s",\n' "$branch"
            printf '  "last_run_iso": "%s",\n' "$now"
            printf '  "doc_root": "%s",\n' "$doc_root"
            printf '  "mkdocs_config": "%s",\n' "$mkdocs_config"
            printf '  "pages_generated": ['
            local sep=""
            for p in "${pages[@]}"; do
                printf '%s"%s"' "$sep" "$p"
                sep=", "
            done
            printf ']\n'
            printf '}\n'
        } > "$STATE"
    fi

    update_index "$key" "$ROOT" "$origin"
    log_ok "state written: $STATE"
}

update_index() {
    local key="$1" root="$2" origin="$3"
    mkdir -p "$(dirname "$INDEX")"
    if $HAVE_JQ; then
        local prior="{}"
        [[ -f "$INDEX" ]] && prior=$(cat "$INDEX")
        echo "$prior" | jq --arg k "$key" --arg r "$root" --arg o "$origin" \
            '.[$k] = {worktree:$r, remote_url:$o}' > "$INDEX.tmp"
        mv "$INDEX.tmp" "$INDEX"
    else
        # No jq: blunt overwrite is fine for the fallback path.
        if [[ ! -f "$INDEX" ]]; then
            echo "{}" > "$INDEX"
        fi
    fi
}

print_delta() {
    local last
    last=$(read_field last_commit)
    if [[ -z "$last" ]]; then
        return 0  # first run; no delta to print
    fi
    if ! git -C "$ROOT" rev-parse --verify --quiet "$last" >/dev/null; then
        return 0  # commit unreachable; mode() will report rebase-fallback
    fi
    if ! git -C "$ROOT" merge-base --is-ancestor "$last" HEAD 2>/dev/null; then
        return 0  # non-linear; mode() will report rebase-fallback
    fi
    git -C "$ROOT" diff --name-only --diff-filter=ACMRD "$last..HEAD" || true
}

print_mode() {
    local last
    last=$(read_field last_commit)
    if [[ -z "$last" ]]; then
        echo "first-run"
        return 0
    fi
    if ! git -C "$ROOT" rev-parse --verify --quiet "$last" >/dev/null; then
        echo "rebase-fallback"
        return 0
    fi
    if ! git -C "$ROOT" merge-base --is-ancestor "$last" HEAD 2>/dev/null; then
        echo "rebase-fallback"
        return 0
    fi
    local head
    head=$(git -C "$ROOT" rev-parse HEAD)
    if [[ "$head" == "$last" ]]; then
        echo "no-op"
        return 0
    fi
    echo "incremental"
}

clear_state() {
    if [[ -f "$STATE" ]]; then
        rm -f "$STATE"
        log_ok "cleared state for $ROOT"
    else
        log_skip "no state to clear for $ROOT"
    fi
}

list_repos() {
    if [[ ! -f "$INDEX" ]]; then
        echo "(no repos documented yet)"
        return 0
    fi
    if $HAVE_JQ; then
        jq -r 'to_entries[] | "\(.key)\t\(.value.worktree)\t\(.value.remote_url)"' "$INDEX"
    else
        cat "$INDEX"
    fi
}

cmd="${1:-read}"
shift || true

case "$cmd" in
    read)         read_state ;;
    write)
        if [[ $# -lt 1 ]]; then
            log_fail "usage: state.sh write <commit> [pages...]"
            exit 2
        fi
        write_state "$@"
        ;;
    delta)        print_delta ;;
    mode)         print_mode ;;
    clear)        clear_state ;;
    list-repos)   list_repos ;;
    *)
        log_fail "unknown subcommand: $cmd"
        echo "usage: state.sh {read|write <commit> [pages...]|delta|mode|clear|list-repos}" >&2
        exit 2
        ;;
esac
