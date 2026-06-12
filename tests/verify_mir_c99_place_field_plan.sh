#!/usr/bin/env bash
#
# MIR-C99 field address/load/store place plan verifier.

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
        echo "error: MIR-C99 field place plan missing evidence: $description" >&2
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
    MIR_C99_MEMORY_OP_KIND_FIELD_ADDR \
    MIR_C99_MEMORY_OP_KIND_FIELD_LOAD \
    MIR_C99_MEMORY_OP_KIND_FIELD_STORE \
    MIR_C99_MEMORY_OP_FLAG_FIELD_ACCESS \
    mir_c99_place_memory_op_bind_field; do
    require_pattern "$PLACE_FILE" "$symbol" "field place symbol $symbol"
done

require_pattern "$PLACE_FILE" 'MIR_INST_OP_FIELD_ADDR' \
    "field address opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_FIELD_LOAD' \
    "field load opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_FIELD_STORE' \
    "field store opcode handled"
require_pattern "$PLACE_FILE" 'field_operand_id:[[:space:]]*MirOperandId' \
    "field descriptor operand captured"
require_pattern "$PLACE_FILE" 'field_index:[[:space:]]*i32' \
    "field index captured"
require_pattern "$PLACE_FILE" 'field_type_id:[[:space:]]*MirTypeId' \
    "field type captured"
require_pattern "$PLACE_FILE" 'owner_type_id:[[:space:]]*MirTypeId' \
    "owner aggregate type captured"
require_pattern "$PLACE_FILE" 'field_descriptor\.immediate_i32' \
    "field descriptor immediate index read"
require_pattern "$PLACE_FILE" 'field\.field_type_id' \
    "field layout type read"
require_pattern "$PLACE_FILE" 'owner\.field_start \+ field_descriptor\.immediate_i32' \
    "field layout selected from owner range"
require_pattern "$PLACE_FILE" 'base_operand_id:[[:space:]]*MirOperandId' \
    "field base operand captured"
require_pattern "$PLACE_FILE" 'base_value_id:[[:space:]]*MirValueId' \
    "field base value captured"
require_pattern "$PLACE_FILE" 'base_local_id:[[:space:]]*MirLocalId' \
    "field base local captured"
require_pattern "$PLACE_FILE" 'entry\.flags = entry\.flags \| MIR_C99_MEMORY_OP_FLAG_FIELD_ACCESS' \
    "field access flag recorded"
require_pattern "$DRIVER_FILE" 'mir_c99_place_memory_plan_build' \
    "driver still builds place/memory plan"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$PLACE_FILE"; then
    echo "error: MIR-C99 field place must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_place_field_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 field address/load/store place plan verified"
