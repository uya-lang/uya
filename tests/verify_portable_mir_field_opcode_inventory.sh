#!/usr/bin/env bash
#
# PortableMIR field address/load/store opcode inventory verifier.

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
        echo "error: PortableMIR field opcode inventory missing evidence: $description" >&2
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
    MIR_INST_OP_FIELD_ADDR \
    MIR_INST_OP_FIELD_LOAD \
    MIR_INST_OP_FIELD_STORE \
    MIR_INST_OP_FIELD_MIN \
    MIR_INST_OP_FIELD_MAX \
    portable_mir_inst_op_is_field_place; do
    require_pattern "$MIR_FILE" "$symbol" "MIR field symbol $symbol"
done

for symbol in \
    portable_mir_verify_field_place_inst \
    portable_mir_verify_field_descriptor \
    portable_mir_verify_field_base_operand \
    portable_mir_verify_field_result_or_store; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier field helper $symbol"
done

require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_FIELD_ADDR' \
    "field address opcode verified"
require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_FIELD_LOAD' \
    "field load opcode verified"
require_pattern "$VERIFIER_FILE" 'inst\.op == MIR_INST_OP_FIELD_STORE' \
    "field store opcode verified"
require_pattern "$VERIFIER_FILE" 'field_descriptor\.immediate_i32' \
    "field index read from descriptor operand"
require_pattern "$VERIFIER_FILE" 'owner\.field_start \+ field_descriptor\.immediate_i32' \
    "field layout index uses owner range"
require_pattern "$VERIFIER_FILE" 'field\.field_type_id' \
    "field type metadata consumed"
require_pattern "$VERIFIER_FILE" 'pointer_type\.pointee_type_id' \
    "field address result pointer pointee checked"
require_pattern "$TODO_FILE" 'field address / load / store opcode' \
    "todo records field opcode leaf"

if grep -Eq 'MIR_INST_OP_FIELD_ADDR' "$REPO_ROOT/src/lower/mir_contract.uya" &&
   ! grep -Eq 'MIR_INST_OP_FIELD_ADDR' "$MIR_FILE"; then
    echo "error: field opcodes exist only in mir_contract.uya, not real PortableMIR" >&2
    exit 1
fi

echo "OK: PortableMIR field address/load/store opcode inventory verified"
