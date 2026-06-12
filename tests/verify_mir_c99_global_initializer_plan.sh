#!/usr/bin/env bash
#
# MIR-C99 global scalar/aggregate/string initializer plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
OUTPUT_FILE="$REPO_ROOT/src/codegen/mir_c99/unit_output.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 global initializer plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$PLAN_FILE" "$DRIVER_FILE" "$OUTPUT_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99GlobalInitializerPlanEntry \
    global_initializers \
    mir_c99_global_initializer_plan_append \
    mir_c99_global_initializer_plan_build \
    mir_c99_global_initializer_plan_ptr; do
    require_pattern "$PLAN_FILE" "$symbol" "plan symbol $symbol"
done

require_pattern "$PLAN_FILE" 'MIR_GLOBAL_INIT_SCALAR' \
    "scalar initializer kind consumed from PortableMIR"
require_pattern "$PLAN_FILE" 'MIR_GLOBAL_INIT_AGGREGATE' \
    "aggregate initializer kind consumed from PortableMIR"
require_pattern "$PLAN_FILE" 'MIR_GLOBAL_INIT_STRING' \
    "string initializer kind consumed from PortableMIR"
require_pattern "$PLAN_FILE" 'MIR_CONST_KIND_SCALAR' \
    "scalar const kind validated"
require_pattern "$PLAN_FILE" 'MIR_CONST_KIND_AGGREGATE' \
    "aggregate const kind validated"
require_pattern "$PLAN_FILE" 'MIR_CONST_KIND_STRING' \
    "string const kind validated"
require_pattern "$PLAN_FILE" 'dedupe_id:[[:space:]]*i32' \
    "string dedupe id captured"
require_pattern "$PLAN_FILE" 'byte_count:[[:space:]]*usize' \
    "aggregate/string payload byte count captured"
require_pattern "$PLAN_FILE" 'scalar_i64:[[:space:]]*i64' \
    "scalar initializer payload captured"
require_pattern "$PLAN_FILE" 'mir_c99_plan_append_ref\(plan,[[:space:]]*MIR_C99_REF_KIND_GLOBAL' \
    "program global ref appended"
require_pattern "$PLAN_FILE" 'mir_c99_unit_append_ref\(unit,[[:space:]]*MIR_C99_REF_KIND_GLOBAL' \
    "unit global ref appended"
require_pattern "$DRIVER_FILE" 'mir_c99_global_initializer_plan_build\(request\.module,[[:space:]]*plan,[[:space:]]*primary_unit\)' \
    "driver builds global initializer plan"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_global_initializer' \
    "unit output emits planned global initializers"
require_pattern "$OUTPUT_FILE" 'static int64_t uya_mir_global_' \
    "scalar global emits initialized storage"
require_pattern "$OUTPUT_FILE" 'static uint8_t uya_mir_global_' \
    "aggregate global emits byte storage"
require_pattern "$OUTPUT_FILE" 'static const uint8_t uya_mir_string_' \
    "string global emits deduped byte storage"
require_pattern "$OUTPUT_FILE" 'mir_c99_unit_output_write_i64\(stream,[[:space:]]*init\.scalar_i64\)' \
    "scalar output uses MIR const payload"
require_pattern "$OUTPUT_FILE" 'init\.byte_count' \
    "aggregate/string output uses MIR const byte_count"
require_pattern "$OUTPUT_FILE" 'init\.dedupe_id' \
    "string output uses MIR dedupe id"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' \
    "$PLAN_FILE" "$OUTPUT_FILE"; then
    echo "error: MIR-C99 global initializer path must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_global_initializer_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/calls.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 global scalar/aggregate/string initializer plan verified"
