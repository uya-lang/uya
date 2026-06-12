#!/usr/bin/env bash
#
# PortableMIR error-union CFG metadata verifier.

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
        echo "error: PortableMIR error-union CFG missing evidence: $description" >&2
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
    MIR_INST_OP_ERROR_UNION_OK \
    MIR_INST_OP_ERROR_UNION_ERR \
    MIR_INST_OP_ERROR_UNION_IS_ERR \
    MIR_INST_OP_ERROR_UNION_PAYLOAD \
    MIR_INST_OP_ERROR_UNION_ERROR \
    MIR_ERROR_UNION_PATH_SUCCESS \
    MIR_ERROR_UNION_PATH_FAILURE \
    MIR_INST_FLAG_ERROR_UNION_CHECKED \
    portable_mir_inst_op_is_error_union; do
    require_pattern "$MIR_FILE" "$symbol" "MIR error-union symbol $symbol"
done

for symbol in \
    MIR_INST_OP_ERROR_UNION_OK \
    MIR_INST_OP_ERROR_UNION_ERR \
    MIR_INST_OP_ERROR_UNION_IS_ERR \
    MIR_INST_OP_ERROR_UNION_PAYLOAD \
    MIR_INST_OP_ERROR_UNION_ERROR \
    MIR_ERROR_UNION_PATH_SUCCESS \
    MIR_ERROR_UNION_PATH_FAILURE \
    MIR_INST_FLAG_ERROR_UNION_CHECKED; do
    require_pattern "$CONTRACT_FILE" "$symbol" "contract error-union symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_error_union_inst' \
    "verifier has error-union helper"
require_pattern "$VERIFIER_FILE" 'MIR_INST_FLAG_ERROR_UNION_CHECKED' \
    "verifier requires checked error-union extraction"
require_pattern "$WHITEPAPER_FILE" 'make_error_union_ok' \
    "whitepaper records error-union ok construction"
require_pattern "$WHITEPAPER_FILE" '`try` -> 检查 error-union tag' \
    "whitepaper records try error path"
require_pattern "$TODO_FILE" 'error union success/failure CFG' \
    "todo records error-union CFG leaf"

echo "OK: PortableMIR error-union CFG metadata verified"
