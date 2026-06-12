#!/usr/bin/env bash
#
# MIR-C99 pointer deref load/store place plan verifier.

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
        echo "error: MIR-C99 pointer place plan missing evidence: $description" >&2
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
    MIR_C99_MEMORY_OP_FLAG_POINTER_DEREF \
    mir_c99_place_type_ptr \
    mir_c99_place_operand_is_pointer \
    mir_c99_place_memory_op_bind_pointer; do
    require_pattern "$PLACE_FILE" "$symbol" "pointer place symbol $symbol"
done

require_pattern "$PLACE_FILE" 'pointer_operand_id:[[:space:]]*MirOperandId' \
    "pointer operand id captured"
require_pattern "$PLACE_FILE" 'pointer_value_id:[[:space:]]*MirValueId' \
    "pointer value id captured"
require_pattern "$PLACE_FILE" 'pointer_local_id:[[:space:]]*MirLocalId' \
    "pointer local id captured"
require_pattern "$PLACE_FILE" 'pointee_type_id:[[:space:]]*MirTypeId' \
    "pointee type id captured"
require_pattern "$PLACE_FILE" 'MIR_TYPE_KIND_POINTER' \
    "pointer type kind checked"
require_pattern "$PLACE_FILE" 'typ\.pointee_type_id' \
    "pointee type metadata read"
require_pattern "$PLACE_FILE" 'op_kind == MIR_C99_MEMORY_OP_KIND_LOAD' \
    "load pointer source path handled"
require_pattern "$PLACE_FILE" 'op_kind == MIR_C99_MEMORY_OP_KIND_STORE' \
    "store pointer destination path handled"
require_pattern "$PLACE_FILE" 'entry\.flags = entry\.flags \| MIR_C99_MEMORY_OP_FLAG_POINTER_DEREF' \
    "pointer deref flag recorded"
require_pattern "$DRIVER_FILE" 'mir_c99_place_memory_plan_build' \
    "driver still builds place/memory plan"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$PLACE_FILE"; then
    echo "error: MIR-C99 pointer place must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_place_pointer_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 pointer deref load/store place plan verified"
