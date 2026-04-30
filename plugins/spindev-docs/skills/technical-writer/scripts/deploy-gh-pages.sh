#!/usr/bin/env bash
# Scaffold a GitHub Pages deployment workflow into the consumer repo.
#
# Drops .github/workflows/deploy-mkdocs.yml from templates/. Idempotent:
# never overwrites an existing workflow file. After it lands the operator
# must enable Pages in repo settings (Source: GitHub Actions) — the script
# prints the steps.
#
# We deliberately do NOT call mkdocs gh-deploy --force here. That command
# pushes a gh-pages branch directly, which conflicts with branch protection
# and obscures the build trail. Modern Pages deployments use the Actions
# upload-pages-artifact + deploy-pages flow.
#
# Usage:
#   ./deploy-gh-pages.sh
#   ./deploy-gh-pages.sh --verify   # report only, write nothing

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$HERE/../templates" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

require_cmd git || exit 1

ROOT="$(resolve_repo_root)" || exit 1
cd "$ROOT"

WORKFLOW_DIR=".github/workflows"
WORKFLOW_FILE="$WORKFLOW_DIR/deploy-mkdocs.yml"

if [[ -f "$WORKFLOW_FILE" ]]; then
    log_skip "$WORKFLOW_FILE already exists"
    log_info "remove it manually if you want a fresh scaffold"
    exit 0
fi

if $VERIFY_MODE; then
    log_fail "$WORKFLOW_FILE not present"
    exit 1
fi

mkdir -p "$WORKFLOW_DIR"
cp "$TEMPLATE_DIR/deploy-mkdocs.yml.tmpl" "$WORKFLOW_FILE"
log_ok "wrote $WORKFLOW_FILE"

cat <<'EOF'

Next steps:

  1. Commit and push the workflow:
       git add .github/workflows/deploy-mkdocs.yml
       git commit -m "ci: add mkdocs deploy workflow"
       git push

  2. Enable GitHub Pages with the Actions source:
       Settings → Pages → Build and deployment → Source → GitHub Actions

  3. The next push to main that touches docs/, design-docs/, mkdocs.yml,
     or this workflow will publish the site.

  4. To preview locally before pushing:
       mkdocs serve
EOF
