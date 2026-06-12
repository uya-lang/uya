#!/usr/bin/env bash
#
# PortableMIR vector/mask opcode verifier.

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
        echo "error: PortableMIR vector/mask opcode missing evidence: $description" >&2
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
    MIR_INST_OP_VECTOR_SPLAT \
    MIR_INST_OP_VECTOR_LOAD \
    MIR_INST_OP_VECTOR_STORE \
    MIR_INST_OP_VECTOR_SELECT \
    portable_mir_inst_op_is_vector_mask; do
    require_pattern "$MIR_FILE" "$symbol" "MIR vector/mask symbol $symbol"
done

for symbol in \
    MIR_INST_OP_VECTOR_SPLAT \
    MIR_INST_OP_VECTOR_LOAD \
    MIR_INST_OP_VECTOR_STORE \
    MIR_INST_OP_VECTOR_SELECT; do
    require_pattern "$CONTRACT_FILE" "$symbol" "contract vector/mask symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_vector_mask_inst' \
    "verifier has vector/mask instruction helper"
require_pattern "$VERIFIER_FILE" 'portable_mir_inst_op_is_vector_mask' \
    "verifier uses explicit vector/mask opcode classifier"
require_pattern "$VERIFIER_FILE" 'MIR_TYPE_KIND_VECTOR && typ\.kind != MIR_TYPE_KIND_MASK' \
    "verifier rejects scalar vector/mask op type"
require_pattern "$WHITEPAPER_FILE" '@vector\.splat' \
    "whitepaper records vector splat"
require_pattern "$TODO_FILE" 'SIMD vector/mask load/store/splat/select opcode' \
    "todo records vector/mask leaf"

echo "OK: PortableMIR vector/mask opcode inventory verified"
