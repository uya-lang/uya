#!/usr/bin/env bash
#
# PortableMIR array index address/load/store opcode inventory verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR index opcode inventory missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$VERIFIER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_INST_OP_INDEX_ADDR \
    MIR_INST_OP_INDEX_LOAD \
    MIR_INST_OP_INDEX_STORE \
    MIR_INST_OP_INDEX_MIN \
    MIR_INST_OP_INDEX_MAX \
    MIR_INST_FLAG_BOUNDS_CHECKED \
    portable_mir_inst_op_is_index_place; do
    require_pattern "$MIR_FILE" "$symbol" "MIR index symbol $symbol"
done

for symbol in \
    portable_mir_verify_index_place_inst \
    portable_mir_verify_index_base_operand \
    portable_mir_verify_index_operand_bounds \
    portable_mir_verify_index_result_or_store; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier index helper $symbol"
done

require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_INDEX_ADDR' \
    "index address opcode verified"
require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_INDEX_LOAD' \
    "index load opcode verified"
require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_INDEX_STORE' \
    "index store opcode verified"
require_pattern "$VERIFIER_FILE" 'array_type\.element_type_id' \
    "array element type consumed"
require_pattern "$VERIFIER_FILE" 'index_operand\.immediate_i32' \
    "index immediate metadata consumed"
require_pattern "$VERIFIER_FILE" 'MIR_INST_FLAG_BOUNDS_CHECKED' \
    "dynamic index requires bounds metadata"
require_pattern "$VERIFIER_FILE" 'pointer_type\.pointee_type_id' \
    "index address result pointer pointee checked"
require_pattern "$TODO_FILE" 'array index address / load / store opcode' \
    "todo records index opcode leaf"

if grep -Eq 'MIR_INST_OP_INDEX_ADDR' "$REPO_ROOT/src/lower/mir_contract.uya" &&
   ! grep -Eq 'MIR_INST_OP_INDEX_ADDR' "$MIR_FILE"; then
    echo "error: index opcodes exist only in mir_contract.uya, not real PortableMIR" >&2
    exit 1
fi

echo "OK: PortableMIR array index address/load/store opcode inventory verified"
