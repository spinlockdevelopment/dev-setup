#!/usr/bin/env bash
# Inventory the repo and emit JSON for the writer to consume.
#
# Output shape (top-level keys; values may be empty arrays/objects when
# nothing applies):
#
# {
#   "repo_root":     "<abs path>",
#   "repo_name":     "<basename or remote slug>",
#   "remote_url":    "<git@github.com:...>",
#   "head_sha":      "<sha>",
#   "head_branch":   "<branch>",
#   "default_branch": "main|master|...",
#   "top_level":     ["src", "tests", "docs", ...],
#   "languages":     {".py": 42, ".ts": 17, ...},   # extension census
#   "manifests":     {"package.json": "package.json", "pyproject.toml": "pyproject.toml"},
#   "deploy":        {"dockerfile": "Dockerfile", "fly_toml": "fly.toml", "k8s_dirs": [...], "deploy_workflows": [...]},
#   "docs":          {"readme": "README.md", "contributing": "CONTRIBUTING.md", "changelog": "CHANGELOG.md", "claude_md": "CLAUDE.md"},
#   "data_signals":  {"docker_compose": [...], "queue_hints": [...], "db_hints": [...]},
#   "ops":           {"runbooks": [...], "alerts": [...], "slos": [...]},
#   "test_layout":   {"dirs": [...], "frameworks": [...]},
#   "license":       "LICENSE|LICENSE.md|...",
#   "size":          {"files": 1234, "tracked_loc": 56789}
# }

# Inventory pipelines naturally produce empty output when the repo doesn't
# match a probe (no Dockerfile, no k8s/ dir, etc.). With pipefail set, those
# empty pipelines abort the script when grep returns 1 — defeating the
# whole "look for optional signals" point. We rely on -eu plus explicit
# `|| true` on grep-based command substitutions instead.
set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

require_cmd git || exit 1
require_cmd find || exit 1

ROOT="$(resolve_repo_root)" || exit 1

# Helpers --------------------------------------------------------------------

# Print a JSON array from stdin (one item per line). Uses jq when available;
# otherwise falls back to a hand-built array. Hand-built path assumes items
# are already double-quote-safe (paths with literal " are extremely rare in
# the kind of repos this skill targets; if encountered, install jq).
to_json_array() {
    if cmd_exists jq; then
        jq -R . | jq -s .
    else
        local first=true
        printf '['
        while IFS= read -r line; do
            if $first; then
                first=false
            else
                printf ', '
            fi
            printf '"%s"' "${line//\"/\\\"}"
        done
        printf ']'
    fi
}

# Print a JSON object from stdin lines of "key<TAB>value".
kv_to_json_object() {
    if cmd_exists jq; then
        jq -Rn '
            [inputs | split("\t") | {(.[0]): .[1]}] | add // {}
        '
    else
        local first=true
        printf '{'
        while IFS=$'\t' read -r k v; do
            if $first; then
                first=false
            else
                printf ', '
            fi
            printf '"%s": "%s"' "${k//\"/\\\"}" "${v//\"/\\\"}"
        done
        printf '}'
    fi
}

# Enumerate ls-files efficiently. Skip vendor / node_modules / .git etc.
ls_files() {
    git -C "$ROOT" ls-files
}

# Find files relative to repo root, honoring .gitignore via ls-files.
gitfind() {
    local pattern="$1"
    ls_files | grep -E "$pattern" || true
}

# Existence check for a single tracked file.
has() {
    local f="$1"
    git -C "$ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1
}

# Pick the first existing tracked file from a list.
first_of() {
    local f
    for f in "$@"; do
        if has "$f"; then
            echo "$f"
            return 0
        fi
    done
}

# Top-level entries (one per line).
top_level() {
    git -C "$ROOT" ls-tree --name-only HEAD
}

# Extension census across tracked files.
language_census() {
    ls_files | sed -nE 's/.*(\.[A-Za-z0-9_]+)$/\1/p' \
        | sort \
        | uniq -c \
        | awk '{ printf "%s\t%d\n", $2, $1 }'
}

# Default branch hint. Try gh, then git symbolic-ref, then fallback.
default_branch() {
    local out
    out=$(git -C "$ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
        | sed 's@^origin/@@' || true)
    [[ -n "$out" ]] && { echo "$out"; return; }
    if git -C "$ROOT" show-ref --verify --quiet refs/heads/main; then
        echo "main"; return
    fi
    if git -C "$ROOT" show-ref --verify --quiet refs/heads/master; then
        echo "master"; return
    fi
    echo ""
}

# Tracked LOC — `wc -l` against ls-files. Best-effort; skip binaries via -I.
tracked_loc() {
    ls_files | xargs -d '\n' -r grep -Iv -c '' 2>/dev/null \
        | awk -F: '{s+=$NF} END{print s+0}' || echo 0
}

# Build the JSON --------------------------------------------------------------

REPO_NAME=""
ORIGIN=$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null || echo "")
if [[ -n "$ORIGIN" ]]; then
    REPO_NAME=$(basename -s .git "$ORIGIN")
fi
[[ -z "$REPO_NAME" ]] && REPO_NAME=$(basename "$ROOT")

HEAD_SHA=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "")
HEAD_BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
DEFAULT_BRANCH=$(default_branch)

TOP_LEVEL_JSON=$(top_level | to_json_array)

LANG_KV=$(language_census)
if [[ -n "$LANG_KV" ]]; then
    LANG_JSON=$(echo "$LANG_KV" | awk -F'\t' '{printf "%s\t%s\n", $1, $2}' | kv_to_json_object)
else
    LANG_JSON="{}"
fi

# Manifests
MANIFESTS=()
for m in package.json pyproject.toml Cargo.toml go.mod Gemfile composer.json \
         requirements.txt setup.py setup.cfg build.gradle pom.xml \
         Pipfile mix.exs Package.swift Podfile deno.json; do
    has "$m" && MANIFESTS+=("$m"$'\t'"$m")
done
if (( ${#MANIFESTS[@]} > 0 )); then
    MANIFESTS_JSON=$(printf "%s\n" "${MANIFESTS[@]}" | kv_to_json_object)
else
    MANIFESTS_JSON="{}"
fi

# Deploy artifacts
DOCKERFILE=$(first_of Dockerfile docker/Dockerfile || true)
FLY_TOML=$(first_of fly.toml || true)
K8S_DIRS_JSON=$(ls_files | grep -E '^(k8s|kubernetes|deploy|manifests)/' \
    | awk -F/ '{print $1}' | sort -u | to_json_array)
DEPLOY_WORKFLOWS_JSON=$(gitfind '^\.github/workflows/.*deploy.*\.ya?ml$' | to_json_array)

# Docs surface
README=$(first_of README.md README.rst README.txt readme.md || true)
CONTRIBUTING=$(first_of CONTRIBUTING.md CONTRIBUTING.rst contributing.md || true)
CHANGELOG=$(first_of CHANGELOG.md CHANGELOG.rst HISTORY.md || true)
CLAUDE_MD=$(first_of CLAUDE.md GEMINI.md AGENTS.md || true)

# Data flow signals
COMPOSE_JSON=$(gitfind '(^|/)docker-compose(\.[^/]*)?\.ya?ml$' | to_json_array)
QUEUE_HINTS_JSON=$(gitfind '(rabbitmq|kafka|redis|sqs|pubsub|nats)' | head -50 | to_json_array)
DB_HINTS_JSON=$(gitfind '(schema\.sql|migrations?/|alembic|prisma/|knexfile|sequelize)' | head -50 | to_json_array)

# Ops surface
RUNBOOKS_JSON=$(gitfind '(runbook|playbook|ops/)' | head -50 | to_json_array)
ALERTS_JSON=$(gitfind '(alerts?\.ya?ml|prometheus.*\.ya?ml|alertmanager)' | head -50 | to_json_array)
SLOS_JSON=$(gitfind '(slo|service-level)' | head -50 | to_json_array)

# Test layout
TEST_DIRS_JSON=$(top_level | grep -Ei '^(tests?|spec|__tests__)$' | to_json_array)
TEST_FW_HINTS=()
has package.json && grep -qE '"(jest|vitest|mocha|playwright|cypress)"' "$ROOT/package.json" 2>/dev/null \
    && TEST_FW_HINTS+=("$(grep -oE '"(jest|vitest|mocha|playwright|cypress)"' "$ROOT/package.json" | tr -d '"' | sort -u | tr '\n' ',' | sed 's/,$//')")
has pyproject.toml && grep -qE '(pytest|tox)' "$ROOT/pyproject.toml" 2>/dev/null \
    && TEST_FW_HINTS+=("pytest")
has Cargo.toml && TEST_FW_HINTS+=("cargo-test")
has go.mod && TEST_FW_HINTS+=("go-test")
TEST_FW_JSON=$(printf "%s\n" "${TEST_FW_HINTS[@]}" | grep -v '^$' | to_json_array)

LICENSE=$(first_of LICENSE LICENSE.md LICENSE.txt COPYING || true)

FILES_COUNT=$(ls_files | wc -l | tr -d ' ')
LOC=$(tracked_loc)

emit_str() {
    local v="$1"
    if [[ -z "$v" ]]; then
        echo "null"
    else
        printf '"%s"' "${v//\"/\\\"}"
    fi
}

cat <<EOF
{
  "repo_root": "$ROOT",
  "repo_name": "$REPO_NAME",
  "remote_url": $(emit_str "$ORIGIN"),
  "head_sha": "$HEAD_SHA",
  "head_branch": "$HEAD_BRANCH",
  "default_branch": $(emit_str "$DEFAULT_BRANCH"),
  "top_level": $TOP_LEVEL_JSON,
  "languages": $LANG_JSON,
  "manifests": $MANIFESTS_JSON,
  "deploy": {
    "dockerfile": $(emit_str "$DOCKERFILE"),
    "fly_toml": $(emit_str "$FLY_TOML"),
    "k8s_dirs": $K8S_DIRS_JSON,
    "deploy_workflows": $DEPLOY_WORKFLOWS_JSON
  },
  "docs": {
    "readme": $(emit_str "$README"),
    "contributing": $(emit_str "$CONTRIBUTING"),
    "changelog": $(emit_str "$CHANGELOG"),
    "claude_md": $(emit_str "$CLAUDE_MD")
  },
  "data_signals": {
    "docker_compose": $COMPOSE_JSON,
    "queue_hints": $QUEUE_HINTS_JSON,
    "db_hints": $DB_HINTS_JSON
  },
  "ops": {
    "runbooks": $RUNBOOKS_JSON,
    "alerts": $ALERTS_JSON,
    "slos": $SLOS_JSON
  },
  "test_layout": {
    "dirs": $TEST_DIRS_JSON,
    "frameworks": $TEST_FW_JSON
  },
  "license": $(emit_str "$LICENSE"),
  "size": {
    "files": $FILES_COUNT,
    "tracked_loc": $LOC
  }
}
EOF
