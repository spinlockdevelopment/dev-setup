#!/usr/bin/env bash
# deploy.sh — wrapper around `fly deploy` that picks up a stored
# deploy token and runs a remote build.
#
# Usage: deploy.sh <app-name>
#   Reads FLY_API_TOKEN from env, falling back to
#   ~/.config/<app>/secrets/fly-deploy-token, then
#   ~/.config/tod/secrets/fly-deploy-token.
#
# Expects to run from a directory containing fly.toml + Dockerfile.

set -euo pipefail

APP="${1:-}"
[[ -n "${APP}" ]] || { echo "usage: $0 <app-name>" >&2; exit 2; }

command -v fly >/dev/null || { echo "flyctl not installed" >&2; exit 1; }
[[ -f fly.toml ]]   || { echo "no fly.toml in $(pwd)" >&2; exit 1; }
[[ -f Dockerfile ]] || { echo "no Dockerfile in $(pwd)" >&2; exit 1; }

TOKEN="${FLY_API_TOKEN:-}"
if [[ -z "${TOKEN}" ]]; then
  for cand in \
      "${HOME}/.config/${APP}/secrets/fly-deploy-token" \
      "${HOME}/.config/tod/secrets/fly-deploy-token"; do
    [[ -f "${cand}" ]] && { TOKEN="$(cat "${cand}")"; break; }
  done
fi
[[ -n "${TOKEN}" ]] || { echo "no FLY_API_TOKEN and no stored token found" >&2; exit 1; }

FLY_API_TOKEN="${TOKEN}" exec fly deploy --app "${APP}" --remote-only
