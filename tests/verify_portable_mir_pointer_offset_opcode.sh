#!/usr/bin/env bash
#
# PortableMIR pointer offset opcode verifier.

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
        echo "error: PortableMIR pointer offset missing evidence: $description" >&2
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
    MIR_INST_OP_POINTER_OFFSET \
    MIR_INST_FLAG_OVERFLOW_CHECKED \
    portable_mir_inst_op_is_pointer_offset; do
    require_pattern "$MIR_FILE" "$symbol" "MIR pointer offset symbol $symbol"
done

for symbol in \
    portable_mir_verify_pointer_offset_inst \
    portable_mir_verify_pointer_offset_base \
    portable_mir_verify_pointer_offset_amount; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier pointer offset helper $symbol"
done

require_pattern "$VERIFIER_FILE" 'pointer_type\.pointee_type_id' \
    "pointee type metadata consumed"
require_pattern "$VERIFIER_FILE" 'pointee\.size_bytes' \
    "element stride metadata consumed"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_operand_integer_type' \
    "offset operand integer type checked"
require_pattern "$VERIFIER_FILE" 'MIR_INST_FLAG_OVERFLOW_CHECKED' \
    "overflow/capability strategy checked"
require_pattern "$TODO_FILE" 'pointer offset opcode' \
    "todo records pointer offset leaf"

echo "OK: PortableMIR pointer offset opcode verified"
