#!/usr/bin/env bash
#
# MIR-C99 value/local scalar temp mapping verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALUE_FILE="$REPO_ROOT/src/codegen/mir_c99/values.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 value plan missing evidence: $description" >&2
        exit 1
    fi
}

if [[ ! -f "$VALUE_FILE" ]]; then
    echo "error: missing MIR-C99 value source: $VALUE_FILE" >&2
    exit 1
fi
if [[ ! -f "$DRIVER_FILE" ]]; then
    echo "error: missing MIR-C99 driver source: $DRIVER_FILE" >&2
    exit 1
fi

for symbol in \
    MirC99ValueTemp \
    MirC99ValuePlan \
    MIR_C99_VALUE_TEMP_KIND_BOOL \
    MIR_C99_VALUE_TEMP_KIND_I32 \
    MIR_C99_VALUE_TEMP_KIND_BYTE \
    MIR_C99_VALUE_TEMP_KIND_USIZE \
    MIR_C99_VALUE_TEMP_KIND_ISIZE \
    MIR_C99_VALUE_TEMP_KIND_F32 \
    MIR_C99_VALUE_TEMP_KIND_F64 \
    mir_c99_value_plan_build \
    mir_c99_value_plan_entry_ptr; do
    require_pattern "$VALUE_FILE" "$symbol" "value symbol $symbol"
done

require_pattern "$VALUE_FILE" 'while i < module\.values\.count' \
    "all MIR values scanned"
require_pattern "$VALUE_FILE" 'value_id:[[:space:]]*MirValueId' \
    "MIR value id captured"
require_pattern "$VALUE_FILE" 'type_id:[[:space:]]*MirTypeId' \
    "MIR value type id captured"
require_pattern "$VALUE_FILE" 'c_temp_source_id:[[:space:]]*i32' \
    "stable C temp source id captured"
require_pattern "$VALUE_FILE" 'MIR_TYPE_KIND_BOOL' \
    "bool scalar type handled"
require_pattern "$VALUE_FILE" 'MIR_TYPE_KIND_I32' \
    "i32 scalar type handled"
require_pattern "$VALUE_FILE" 'MIR_TYPE_KIND_USIZE' \
    "usize scalar type handled"
require_pattern "$DRIVER_FILE" 'use codegen\.mir_c99\.values' \
    "driver imports value plan"
require_pattern "$DRIVER_FILE" 'mir_c99_value_plan_build' \
    "driver builds value plan"
require_pattern "$DRIVER_FILE" 'result\.value_count = value_plan\.count' \
    "driver reports value count"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$VALUE_FILE"; then
    echo "error: MIR-C99 values must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_value_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$VALUE_FILE" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 scalar value temp plan verified"
