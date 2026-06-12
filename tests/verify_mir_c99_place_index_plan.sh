#!/usr/bin/env bash
#
# MIR-C99 array index address/load/store place plan verifier.

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
        echo "error: MIR-C99 index place plan missing evidence: $description" >&2
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
    MIR_C99_MEMORY_OP_KIND_INDEX_ADDR \
    MIR_C99_MEMORY_OP_KIND_INDEX_LOAD \
    MIR_C99_MEMORY_OP_KIND_INDEX_STORE \
    MIR_C99_MEMORY_OP_FLAG_INDEX_ACCESS \
    mir_c99_place_memory_op_bind_index; do
    require_pattern "$PLACE_FILE" "$symbol" "index place symbol $symbol"
done

require_pattern "$PLACE_FILE" 'MIR_INST_OP_INDEX_ADDR' \
    "index address opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_INDEX_LOAD' \
    "index load opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_INDEX_STORE' \
    "index store opcode handled"
require_pattern "$PLACE_FILE" 'index_operand_id:[[:space:]]*MirOperandId' \
    "index operand captured"
require_pattern "$PLACE_FILE" 'index_value_id:[[:space:]]*MirValueId' \
    "dynamic index value captured"
require_pattern "$PLACE_FILE" 'index_local_id:[[:space:]]*MirLocalId' \
    "dynamic index local captured"
require_pattern "$PLACE_FILE" 'index_immediate:[[:space:]]*i32' \
    "static index immediate captured"
require_pattern "$PLACE_FILE" 'element_type_id:[[:space:]]*MirTypeId' \
    "array element type captured"
require_pattern "$PLACE_FILE" 'array_type_id:[[:space:]]*MirTypeId' \
    "array type captured"
require_pattern "$PLACE_FILE" 'array_length:[[:space:]]*i32' \
    "array length captured"
require_pattern "$PLACE_FILE" 'pointer_type\.pointee_type_id' \
    "base pointer pointee array type read"
require_pattern "$PLACE_FILE" 'array_type\.element_type_id' \
    "array element metadata read"
require_pattern "$PLACE_FILE" 'array_type\.field_count' \
    "array length metadata read"
require_pattern "$PLACE_FILE" 'MIR_INST_FLAG_BOUNDS_CHECKED' \
    "dynamic index bounds flag preserved"
require_pattern "$PLACE_FILE" 'entry\.flags = entry\.flags \| MIR_C99_MEMORY_OP_FLAG_INDEX_ACCESS' \
    "index access flag recorded"
require_pattern "$DRIVER_FILE" 'mir_c99_place_memory_plan_build' \
    "driver still builds place/memory plan"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$PLACE_FILE"; then
    echo "error: MIR-C99 index place must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_place_index_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 array index address/load/store place plan verified"
