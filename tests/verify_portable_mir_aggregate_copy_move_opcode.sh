#!/usr/bin/env bash
#
# PortableMIR aggregate copy/move opcode verifier.

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
        echo "error: PortableMIR aggregate copy/move missing evidence: $description" >&2
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
    MIR_INST_OP_AGGREGATE_COPY \
    MIR_INST_OP_AGGREGATE_MOVE \
    MIR_INST_FLAG_NO_OVERLAP \
    portable_mir_inst_op_is_aggregate_copy_move; do
    require_pattern "$MIR_FILE" "$symbol" "MIR aggregate copy/move symbol $symbol"
done

for symbol in \
    portable_mir_verify_aggregate_copy_move_inst \
    portable_mir_verify_aggregate_copy_move_operand \
    portable_mir_verify_aggregate_copy_move_layout; do
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier aggregate copy/move helper $symbol"
done

require_pattern "$VERIFIER_FILE" 'typ\.size_bytes' \
    "aggregate size metadata consumed"
require_pattern "$VERIFIER_FILE" 'typ\.align_bytes' \
    "aggregate align metadata consumed"
require_pattern "$VERIFIER_FILE" 'MIR_INST_FLAG_NO_OVERLAP' \
    "overlap semantics checked"
require_pattern "$VERIFIER_FILE" 'pointer_type\.pointee_type_id' \
    "source/dest pointer pointee checked"
require_pattern "$TODO_FILE" 'aggregate copy / move opcode' \
    "todo records aggregate copy/move leaf"

echo "OK: PortableMIR aggregate copy/move opcode verified"
