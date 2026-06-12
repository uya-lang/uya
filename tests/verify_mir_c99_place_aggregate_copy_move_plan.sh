#!/usr/bin/env bash
#
# MIR-C99 aggregate copy/move memcpy helper place plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLACE_FILE="$REPO_ROOT/src/codegen/mir_c99/place_memory.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 aggregate copy/move plan missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$PLACE_FILE" "$DRIVER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_MEMORY_OP_KIND_AGGREGATE_COPY \
    MIR_C99_MEMORY_OP_KIND_AGGREGATE_MOVE \
    MIR_C99_MEMORY_OP_FLAG_MEMCPY_HELPER \
    mir_c99_place_memory_op_bind_aggregate_copy_move; do
    require_pattern "$PLACE_FILE" "$symbol" "aggregate copy/move symbol $symbol"
done

require_pattern "$PLACE_FILE" 'MIR_INST_OP_AGGREGATE_COPY' \
    "aggregate copy opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_AGGREGATE_MOVE' \
    "aggregate move opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_FLAG_NO_OVERLAP' \
    "no-overlap flag checked"
require_pattern "$PLACE_FILE" 'aggregate_type_id:[[:space:]]*MirTypeId' \
    "aggregate type captured"
require_pattern "$PLACE_FILE" 'aggregate_size_bytes:[[:space:]]*usize' \
    "aggregate size captured"
require_pattern "$PLACE_FILE" 'aggregate_align_bytes:[[:space:]]*usize' \
    "aggregate alignment captured"
require_pattern "$PLACE_FILE" 'copy_dest_operand_id:[[:space:]]*MirOperandId' \
    "copy destination operand captured"
require_pattern "$PLACE_FILE" 'copy_source_operand_id:[[:space:]]*MirOperandId' \
    "copy source operand captured"
require_pattern "$PLACE_FILE" 'pointer_type\.pointee_type_id != typ\.type_id' \
    "pointer operand pointee type checked"
require_pattern "$PLACE_FILE" 'entry\.flags = entry\.flags \| MIR_C99_MEMORY_OP_FLAG_MEMCPY_HELPER' \
    "memcpy helper flag recorded"
require_pattern "$DRIVER_FILE" 'mir_c99_place_memory_plan_build' \
    "driver still builds place/memory plan"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$PLACE_FILE"; then
    echo "error: MIR-C99 aggregate copy/move place must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_place_aggregate_copy_move_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$PLACE_FILE" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 aggregate copy/move memcpy helper place plan verified"
