#!/usr/bin/env bash
#
# MIR-C99 local slot/load/store place plan verifier.

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
        echo "error: MIR-C99 local place plan missing evidence: $description" >&2
        exit 1
    fi
}

if [[ ! -f "$PLACE_FILE" ]]; then
    echo "error: missing MIR-C99 place/memory source: $PLACE_FILE" >&2
    exit 1
fi
if [[ ! -f "$DRIVER_FILE" ]]; then
    echo "error: missing MIR-C99 driver source: $DRIVER_FILE" >&2
    exit 1
fi

for symbol in \
    MirC99LocalSlotEntry \
    MirC99MemoryOpEntry \
    MirC99PlaceMemoryPlan \
    MIR_C99_MEMORY_OP_KIND_LOAD \
    MIR_C99_MEMORY_OP_KIND_STORE \
    MIR_C99_MEMORY_OP_KIND_LOCAL_SET \
    mir_c99_place_memory_plan_build \
    mir_c99_place_memory_plan_local_ptr \
    mir_c99_place_memory_plan_op_ptr; do
    require_pattern "$PLACE_FILE" "$symbol" "place/memory symbol $symbol"
done

require_pattern "$PLACE_FILE" 'while i < module\.locals\.count' \
    "all MIR locals scanned"
require_pattern "$PLACE_FILE" 'while i < module\.insts\.count' \
    "all MIR memory instructions scanned"
require_pattern "$PLACE_FILE" 'local_id:[[:space:]]*MirLocalId' \
    "local id captured"
require_pattern "$PLACE_FILE" 'type_id:[[:space:]]*MirTypeId' \
    "local/type id captured"
require_pattern "$PLACE_FILE" 'c_slot_source_id:[[:space:]]*i32' \
    "stable C slot source id captured"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_LOAD' \
    "load opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_STORE' \
    "store opcode handled"
require_pattern "$PLACE_FILE" 'MIR_INST_OP_LOCAL_SET' \
    "local set opcode handled"
require_pattern "$PLACE_FILE" 'dest_local_id:[[:space:]]*MirLocalId' \
    "store destination local captured"
require_pattern "$PLACE_FILE" 'source_value_id:[[:space:]]*MirValueId' \
    "source value captured"
require_pattern "$DRIVER_FILE" 'use codegen\.mir_c99\.place_memory' \
    "driver imports place/memory plan"
require_pattern "$DRIVER_FILE" 'mir_c99_place_memory_plan_build' \
    "driver builds place/memory plan"
require_pattern "$DRIVER_FILE" 'result\.local_count = place_plan\.local_count' \
    "driver reports local count"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$PLACE_FILE"; then
    echo "error: MIR-C99 place/memory must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_place_local_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 local slot/load/store place plan verified"
