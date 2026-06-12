#!/usr/bin/env bash
#
# PortableMIR cleanup/drop metadata verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
WHITEPAPER_FILE="$REPO_ROOT/docs/portable_mir_whitepaper.md"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR cleanup/drop missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$CONTRACT_FILE" "$VERIFIER_FILE" "$WHITEPAPER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_INST_OP_DROP_VALUE \
    MIR_INST_OP_DROP_IN_PLACE \
    MIR_CLEANUP_MODEL_RETURN \
    MIR_CLEANUP_MODEL_ERROR \
    MIR_CLEANUP_MODEL_UNWIND \
    MIR_CLEANUP_EDGE_KIND_RETURN \
    MIR_CLEANUP_EDGE_KIND_ERROR \
    MIR_CLEANUP_EDGE_KIND_UNWIND \
    MIR_CLEANUP_ACTION_DEFER \
    MIR_CLEANUP_ACTION_ERRDEFER \
    MIR_CLEANUP_ACTION_LEXICAL_DROP \
    portable_mir_inst_op_is_drop; do
    require_pattern "$MIR_FILE" "$symbol" "MIR cleanup/drop symbol $symbol"
done

for symbol in \
    MIR_INST_OP_DROP_VALUE \
    MIR_INST_OP_DROP_IN_PLACE \
    MIR_CLEANUP_MODEL_RETURN \
    MIR_CLEANUP_MODEL_ERROR \
    MIR_CLEANUP_MODEL_UNWIND \
    MIR_CLEANUP_EDGE_KIND_RETURN \
    MIR_CLEANUP_EDGE_KIND_ERROR \
    MIR_CLEANUP_EDGE_KIND_UNWIND \
    MIR_CLEANUP_ACTION_DEFER \
    MIR_CLEANUP_ACTION_ERRDEFER \
    MIR_CLEANUP_ACTION_LEXICAL_DROP; do
    require_pattern "$CONTRACT_FILE" "$symbol" "contract cleanup/drop symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_drop_inst' \
    "verifier has drop instruction helper"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_cleanup_model_known' \
    "verifier rejects unknown cleanup model bits"
require_pattern "$VERIFIER_FILE" 'MIR_CLEANUP_MODEL_UNWIND' \
    "verifier knows unwind cleanup model"
require_pattern "$WHITEPAPER_FILE" 'defer / errdefer' \
    "whitepaper records defer/errdefer cleanup"
require_pattern "$TODO_FILE" 'cleanup edge、drop opcode 和 unwind/error path metadata' \
    "todo records cleanup/drop leaf"

echo "OK: PortableMIR cleanup/drop metadata verified"
