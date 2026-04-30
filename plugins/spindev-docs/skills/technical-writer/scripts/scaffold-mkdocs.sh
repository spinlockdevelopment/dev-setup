#!/usr/bin/env bash
# Scaffold mkdocs.yml + the docs root skeleton from templates.
#
# Decisions made here (idempotently):
#   1. doc_root: prefer "docs" if free; else "design-docs". Never overwrite
#      an existing docs/ that is not already a mkdocs site.
#   2. mkdocs.yml: write only if missing. Never clobber an existing config.
#   3. .gitignore: append "site/" if not already present.
#   4. Drop the seed templates (index.md is always written; section seeds
#      are dropped only when the file does not yet exist).
#
# The agent fills the seed files with prose on the next step.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$HERE/../templates" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

require_cmd git || exit 1

ROOT="$(resolve_repo_root)" || exit 1
cd "$ROOT"

# Decide doc_root --------------------------------------------------------------
# - If the user passed DOCS_DIR=..., honor it.
# - Else, prefer "docs" if it's empty / non-existent / already mkdocs.
# - Else fall back to "design-docs".
is_mkdocs_site() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    [[ -f "$dir/index.md" ]] || return 1
    [[ -f "mkdocs.yml" ]]
}

DOCS_DIR="${DOCS_DIR:-}"
if [[ -z "$DOCS_DIR" ]]; then
    if [[ ! -e docs ]] || is_mkdocs_site docs || \
       { [[ -d docs ]] && [[ -z "$(ls -A docs 2>/dev/null)" ]]; }; then
        DOCS_DIR="docs"
    else
        DOCS_DIR="design-docs"
        log_info "existing docs/ detected; using design-docs/ instead"
    fi
fi

mkdir -p "$DOCS_DIR"

# Write mkdocs.yml if missing --------------------------------------------------
SITE_NAME=""
if origin=$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null); then
    SITE_NAME=$(basename -s .git "$origin")
fi
[[ -z "$SITE_NAME" ]] && SITE_NAME=$(basename "$ROOT")

REPO_URL=""
if origin=$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null); then
    case "$origin" in
        git@github.com:*)
            REPO_URL="https://github.com/${origin#git@github.com:}"
            REPO_URL="${REPO_URL%.git}"
            ;;
        https://*)
            REPO_URL="${origin%.git}"
            ;;
    esac
fi

if [[ ! -f mkdocs.yml ]]; then
    if $VERIFY_MODE; then
        log_fail "mkdocs.yml missing (verify mode — not creating)"
        exit 1
    fi
    log_info "scaffolding mkdocs.yml"
    sed \
        -e "s|@@SITE_NAME@@|$SITE_NAME|g" \
        -e "s|@@DOCS_DIR@@|$DOCS_DIR|g" \
        -e "s|@@REPO_URL@@|$REPO_URL|g" \
        "$TEMPLATE_DIR/mkdocs.yml.tmpl" > mkdocs.yml
    log_ok "mkdocs.yml written"
else
    log_skip "mkdocs.yml already present"
fi

# Drop section seeds (only if the file does not exist yet) ---------------------
# Section files: written empty-ish with a placeholder comment so mkdocs build
# --strict doesn't fail. The agent overwrites them with real prose.
seed_if_missing() {
    local tmpl="$1" dest="$2"
    if [[ -f "$dest" ]]; then
        log_skip "exists: $dest"
        return 0
    fi
    if $VERIFY_MODE; then
        log_fail "missing: $dest"
        return 1
    fi
    sed \
        -e "s|@@SITE_NAME@@|$SITE_NAME|g" \
        -e "s|@@DOCS_DIR@@|$DOCS_DIR|g" \
        -e "s|@@REPO_URL@@|$REPO_URL|g" \
        "$TEMPLATE_DIR/$tmpl" > "$dest"
    log_ok "seeded: $dest"
}

# Always seed index.md. The other section seeds are NOT written here — the
# agent decides which of them to materialize based on scan output, and writes
# them directly.
seed_if_missing index.md.tmpl "$DOCS_DIR/index.md"

# Theme override CSS — minimalist black/white tweaks on top of mkdocs-material.
# Referenced from mkdocs.yml as `extra_css: [assets/overrides.css]`.
mkdir -p "$DOCS_DIR/assets"
seed_if_missing overrides.css.tmpl "$DOCS_DIR/assets/overrides.css"

# .gitignore: ensure site/ is ignored ------------------------------------------
GITIGNORE="$ROOT/.gitignore"
if [[ ! -f "$GITIGNORE" ]] || ! grep -qE '^site/?$' "$GITIGNORE"; then
    if $VERIFY_MODE; then
        log_fail "site/ not in .gitignore"
    else
        printf '\n# mkdocs build output\nsite/\n' >> "$GITIGNORE"
        log_ok "added site/ to .gitignore"
    fi
else
    log_skip "site/ already in .gitignore"
fi

# .pages (awesome-pages plugin) — optional nav-order hint at the doc root.
# We leave this out by default; users can enable it by dropping a .pages file
# in $DOCS_DIR. The template is provided for reference.

echo "$DOCS_DIR"
