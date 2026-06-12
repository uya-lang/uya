#!/usr/bin/env bash
#
# PortableMIR slice ptr/len/index opcode inventory verifier.

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
        echo "error: PortableMIR slice opcode inventory missing evidence: $description" >&2
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
    MIR_INST_OP_SLICE_PTR_ADDR \
    MIR_INST_OP_SLICE_PTR_LOAD \
    MIR_INST_OP_SLICE_LEN_ADDR \
    MIR_INST_OP_SLICE_LEN_LOAD \
    MIR_INST_OP_SLICE_INDEX_ADDR \
    MIR_INST_OP_SLICE_INDEX_LOAD \
    MIR_INST_OP_SLICE_INDEX_STORE \
    MIR_INST_OP_SLICE_MIN \
    MIR_INST_OP_SLICE_MAX \
    portable_mir_inst_op_is_slice_place; do
    require_pattern "$MIR_FILE" "$symbol" "MIR slice symbol $symbol"
done

for symbol in \
    portable_mir_verify_slice_place_inst \
    portable_mir_verify_slice_base_operand \
    portable_mir_verify_slice_index_bounds \
    portable_mir_verify_slice_result_or_store; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier slice helper $symbol"
done

require_pattern "$VERIFIER_FILE" 'MIR_INST_OP_SLICE_PTR_ADDR' \
    "slice ptr address opcode verified"
require_pattern "$VERIFIER_FILE" 'MIR_INST_OP_SLICE_LEN_ADDR' \
    "slice len address opcode verified"
require_pattern "$VERIFIER_FILE" 'MIR_INST_OP_SLICE_INDEX_ADDR' \
    "slice index address opcode verified"
require_pattern "$VERIFIER_FILE" 'slice_type\.pointee_type_id' \
    "slice ptr metadata consumed"
require_pattern "$VERIFIER_FILE" 'slice_type\.element_type_id' \
    "slice element metadata consumed"
require_pattern "$VERIFIER_FILE" 'MIR_INST_FLAG_BOUNDS_CHECKED' \
    "slice index requires bounds metadata"
require_pattern "$VERIFIER_FILE" 'MIR_TYPE_KIND_USIZE' \
    "slice len result type checked"
require_pattern "$TODO_FILE" 'slice ptr / len / index address opcode' \
    "todo records slice opcode leaf"

if grep -Eq 'MIR_INST_OP_SLICE_(PTR|LEN)_ADDR' "$REPO_ROOT/src/lower/mir_contract.uya" &&
   ! grep -Eq 'MIR_INST_OP_SLICE_PTR_ADDR' "$MIR_FILE"; then
    echo "error: slice opcodes exist only in mir_contract.uya, not real PortableMIR" >&2
    exit 1
fi

echo "OK: PortableMIR slice ptr/len/index opcode inventory verified"
