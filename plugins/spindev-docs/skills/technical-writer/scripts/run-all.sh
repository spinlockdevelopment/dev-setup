#!/usr/bin/env bash
# Orchestrator. The agent (Claude/Codex/Gemini) is expected to call this,
# read the JSON it emits, write/update the doc pages itself, and then call
# state.sh write to record the run.
#
# This script does the mechanical bits — preflight, scaffolding, scan,
# delta detection, build validation. It does NOT write doc prose; that's
# the model's job. The model calls back into state.sh write at the end.
#
# Modes:
#   ./run-all.sh                 # normal run (mechanical bits only)
#   ./run-all.sh --verify        # read-only: tooling + state + delta report
#   ./run-all.sh --full-regen    # force-full hint exposed to the agent
#
# Output (stdout): a JSON envelope the agent consumes. Status messages
# go to stderr.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

# Status to stderr so stdout stays JSON-clean.
exec 3>&1
exec 1>&2

require_cmd git || exit 1

ROOT="$(resolve_repo_root)" || exit 1
cd "$ROOT"

log_step "technical-writer run-all (verify=$VERIFY_MODE, full-regen=$FULL_REGEN)"

# 1. Preflight ----------------------------------------------------------------
if $VERIFY_MODE; then
    bash "$HERE/preflight.sh" --verify || true
else
    bash "$HERE/preflight.sh"
fi

# 2. State + mode -------------------------------------------------------------
MODE=$(bash "$HERE/state.sh" mode || echo "first-run")
if $FULL_REGEN; then
    MODE="full"
fi
log_info "mode: $MODE"

DELTA_LIST=""
if [[ "$MODE" == "incremental" ]]; then
    DELTA_LIST=$(bash "$HERE/state.sh" delta || true)
fi

PRIOR_STATE=$(bash "$HERE/state.sh" read)
# state.sh read always emits valid JSON (empty: {}; populated: full object).
[[ -z "$PRIOR_STATE" ]] && PRIOR_STATE="{}"

# 3. Scaffold (only when we're going to write; agent decides full vs incr) ----
DOCS_DIR=""
if ! $VERIFY_MODE; then
    DOCS_DIR=$(bash "$HERE/scaffold-mkdocs.sh" | tail -n1)
else
    # In verify mode, derive doc_root from prior state if any.
    if cmd_exists jq; then
        DOCS_DIR=$(echo "$PRIOR_STATE" | jq -r '.doc_root // ""')
    fi
    [[ -z "$DOCS_DIR" ]] && DOCS_DIR="docs"
fi

# 4. Scan ---------------------------------------------------------------------
SCAN_JSON=$(bash "$HERE/scan-repo.sh")

# 5. Build the envelope -------------------------------------------------------
HEAD_SHA=$(git rev-parse HEAD)

# Convert delta list to a JSON array.
if cmd_exists jq; then
    if [[ -n "$DELTA_LIST" ]]; then
        DELTA_JSON=$(printf "%s\n" "$DELTA_LIST" | jq -R . | jq -s .)
    else
        DELTA_JSON="[]"
    fi
else
    DELTA_JSON="[]"
fi

WORKFLOW_PRESENT=false
[[ -f "$ROOT/.github/workflows/deploy-mkdocs.yml" ]] && WORKFLOW_PRESENT=true

# Emit envelope to fd 3 (real stdout).
{
    if cmd_exists jq; then
        jq -n \
            --arg mode "$MODE" \
            --arg head_sha "$HEAD_SHA" \
            --arg docs_dir "$DOCS_DIR" \
            --argjson scan "$SCAN_JSON" \
            --argjson prior_state "$PRIOR_STATE" \
            --argjson delta "$DELTA_JSON" \
            --arg verify_mode "$VERIFY_MODE" \
            --arg full_regen "$FULL_REGEN" \
            --arg workflow_present "$WORKFLOW_PRESENT" \
            '{
                mode: $mode,
                head_sha: $head_sha,
                docs_dir: $docs_dir,
                verify_mode: ($verify_mode == "true"),
                full_regen: ($full_regen == "true"),
                workflow_present: ($workflow_present == "true"),
                prior_state: $prior_state,
                delta_files: $delta,
                scan: $scan
            }'
    else
        # Fallback envelope: still valid JSON, but nests scan/prior_state as
        # raw strings since we can't safely splice them without jq.
        printf '{\n'
        printf '  "mode": "%s",\n' "$MODE"
        printf '  "head_sha": "%s",\n' "$HEAD_SHA"
        printf '  "docs_dir": "%s",\n' "$DOCS_DIR"
        printf '  "verify_mode": %s,\n' "$VERIFY_MODE"
        printf '  "full_regen": %s,\n' "$FULL_REGEN"
        printf '  "workflow_present": %s,\n' "$WORKFLOW_PRESENT"
        printf '  "prior_state_raw": %s,\n' "${PRIOR_STATE//$'\n'/}"
        printf '  "scan_raw": %s,\n' "${SCAN_JSON//$'\n'/}"
        printf '  "delta_files": []\n'
        printf '}\n'
    fi
} >&3

if $VERIFY_MODE; then
    log_step "verify summary"
    log_info "mode: $MODE"
    log_info "docs dir: $DOCS_DIR"
    if [[ -n "$DELTA_LIST" ]]; then
        echo "$DELTA_LIST" | sed 's/^/  /'
    fi
    log_ok "verify run complete (no writes)"
fi
