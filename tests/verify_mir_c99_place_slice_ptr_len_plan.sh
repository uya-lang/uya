#!/usr/bin/env bash
#
# MIR-C99 slice ptr/len address/load place plan verifier.

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
        echo "error: MIR-C99 slice ptr/len place plan missing evidence: $description" >&2
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
    MIR_C99_MEMORY_OP_KIND_SLICE_PTR_ADDR \
    MIR_C99_MEMORY_OP_KIND_SLICE_PTR_LOAD \
    MIR_C99_MEMORY_OP_KIND_SLICE_LEN_ADDR \
    MIR_C99_MEMORY_OP_KIND_SLICE_LEN_LOAD \
    MIR_C99_MEMORY_OP_FLAG_SLICE_COMPONENT \
    mir_c99_place_memory_op_bind_slice_component; do
    require_pattern "$PLACE_FILE" "$symbol" "slice ptr/len symbol $symbol"
done

require_pattern "$PLACE_FILE" 'MIR_INST_OP_SLICE_PTR_ADDR' \
    "slice ptr address opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_SLICE_PTR_LOAD' \
    "slice ptr load opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_SLICE_LEN_ADDR' \
    "slice len address opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_SLICE_LEN_LOAD' \
    "slice len load opcode handled"
require_pattern "$PLACE_FILE" 'slice_component_kind:[[:space:]]*i32' \
    "slice component kind captured"
require_pattern "$PLACE_FILE" 'slice_type_id:[[:space:]]*MirTypeId' \
    "slice type captured"
require_pattern "$PLACE_FILE" 'slice_ptr_type_id:[[:space:]]*MirTypeId' \
    "slice ptr type captured"
require_pattern "$PLACE_FILE" 'slice_len_type_id:[[:space:]]*MirTypeId' \
    "slice len type captured"
require_pattern "$PLACE_FILE" 'slice_type\.pointee_type_id' \
    "slice ptr metadata read"
require_pattern "$PLACE_FILE" 'MIR_TYPE_KIND_USIZE' \
    "slice len type checked"
require_pattern "$PLACE_FILE" 'entry\.flags = entry\.flags \| MIR_C99_MEMORY_OP_FLAG_SLICE_COMPONENT' \
    "slice component flag recorded"
require_pattern "$DRIVER_FILE" 'mir_c99_place_memory_plan_build' \
    "driver still builds place/memory plan"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$PLACE_FILE"; then
    echo "error: MIR-C99 slice ptr/len place must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_place_slice_ptr_len_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 slice ptr/len address/load place plan verified"
