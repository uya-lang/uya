#!/usr/bin/env bash
#
# MIR-C99 f32/f64 layout usage verifier for aggregates, arrays, slices, returns and params.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TYPE_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 float layout plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$TYPE_FILE" "$VERIFIER_FILE" "$MIR_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99FloatLayoutUseEntry \
    float_layout_uses \
    float_layout_use_count \
    mir_c99_type_plan_append_float_layout_use \
    mir_c99_type_plan_float_layout_use_ptr; do
    require_pattern "$TYPE_FILE" "$symbol" "float layout use symbol $symbol"
done

for symbol in \
    MIR_C99_FLOAT_LAYOUT_USE_AGGREGATE_FIELD \
    MIR_C99_FLOAT_LAYOUT_USE_ARRAY_ELEMENT \
    MIR_C99_FLOAT_LAYOUT_USE_SLICE_ELEMENT \
    MIR_C99_FLOAT_LAYOUT_USE_RETURN_VALUE \
    MIR_C99_FLOAT_LAYOUT_USE_PARAM; do
    require_pattern "$TYPE_FILE" "$symbol" "float layout use kind $symbol"
done

require_pattern "$TYPE_FILE" 'float_type_id:[[:space:]]*MirTypeId' \
    "float type id captured"
require_pattern "$TYPE_FILE" 'container_type_id:[[:space:]]*MirTypeId' \
    "container/signature type captured"
require_pattern "$TYPE_FILE" 'size_bytes:[[:space:]]*usize' \
    "float size captured"
require_pattern "$TYPE_FILE" 'align_bytes:[[:space:]]*usize' \
    "float alignment captured"
require_pattern "$TYPE_FILE" 'typ\.kind == MIR_TYPE_KIND_F32 \|\| typ\.kind == MIR_TYPE_KIND_F64' \
    "f32/f64 type recognized"
require_pattern "$TYPE_FILE" 'field_type\.kind == MIR_TYPE_KIND_F32 \|\| field_type\.kind == MIR_TYPE_KIND_F64' \
    "aggregate float field recognized"
require_pattern "$TYPE_FILE" 'element_type\.kind == MIR_TYPE_KIND_F32 \|\| element_type\.kind == MIR_TYPE_KIND_F64' \
    "array/slice float element recognized"
require_pattern "$TYPE_FILE" 'return_type\.kind == MIR_TYPE_KIND_F32 \|\| return_type\.kind == MIR_TYPE_KIND_F64' \
    "float return type recognized"
require_pattern "$TYPE_FILE" 'param_type\.kind == MIR_TYPE_KIND_F32 \|\| param_type\.kind == MIR_TYPE_KIND_F64' \
    "float param type recognized"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_I32 \|\| typ\.kind == MIR_TYPE_KIND_U32 \|\| typ\.kind == MIR_TYPE_KIND_F32' \
    "verifier keeps f32 four-byte layout"
require_pattern "$VERIFIER_FILE" 'typ\.kind == MIR_TYPE_KIND_I64 \|\| typ\.kind == MIR_TYPE_KIND_U64 \|\| typ\.kind == MIR_TYPE_KIND_ISIZE \|\| typ\.kind == MIR_TYPE_KIND_USIZE \|\| typ\.kind == MIR_TYPE_KIND_F64' \
    "verifier keeps f64 eight-byte layout"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$TYPE_FILE"; then
    echo "error: MIR-C99 float layout plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_type_float_layout_plan.XXXXXX.uya)"
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
    "$REPO_ROOT/src/codegen/mir_c99/driver.uya" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 f32/f64 layout usage plan verified"
