#!/usr/bin/env bash
#
# MIR-C99 constant-model contract verifier for byte/null/float reject metadata
# and string global-initializer ownership.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALUE_FILE="$REPO_ROOT/src/codegen/mir_c99/values.uya"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
MATRIX_DOC="$REPO_ROOT/docs/portable_mir_language_coverage.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 constant model missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$VALUE_FILE" "$PLAN_FILE" "$MATRIX_DOC"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

require_pattern "$VALUE_FILE" 'MIR_C99_VALUE_TEMP_KIND_BYTE' \
    "byte temp kind symbol"
require_pattern "$VALUE_FILE" 'MIR_C99_VALUE_TEMP_KIND_ISIZE' \
    "isize temp kind symbol"
require_pattern "$VALUE_FILE" 'MIR_C99_VALUE_TEMP_KIND_F32' \
    "f32 temp kind symbol"
require_pattern "$VALUE_FILE" 'MIR_C99_VALUE_TEMP_KIND_F64' \
    "f64 temp kind symbol"
require_pattern "$VALUE_FILE" 'typ\.kind == MIR_TYPE_KIND_BYTE' \
    "byte temp/constant path"
require_pattern "$VALUE_FILE" 'typ\.kind == MIR_TYPE_KIND_ISIZE' \
    "isize temp path"
require_pattern "$VALUE_FILE" 'typ\.kind == MIR_TYPE_KIND_F32' \
    "f32 temp/constant path"
require_pattern "$VALUE_FILE" 'typ\.kind == MIR_TYPE_KIND_F64' \
    "f64 temp/constant path"
require_pattern "$VALUE_FILE" 'MIR_C99_CONSTANT_KIND_BYTE_LITERAL' \
    "byte literal constant kind"
require_pattern "$VALUE_FILE" 'MIR_C99_CONSTANT_REJECT_REASON_FLOAT_PAYLOAD' \
    "float payload reject reason"
require_pattern "$VALUE_FILE" 'MIR_C99_VALUE_DIAG_UNSUPPORTED_FLOAT_CONSTANT_PAYLOAD' \
    "float payload diagnostic"
require_pattern "$VALUE_FILE" 'typ\.kind == MIR_TYPE_KIND_F32 \|\| typ\.kind == MIR_TYPE_KIND_F64' \
    "float payload reject helper"
require_pattern "$VALUE_FILE" 'operand\.immediate_i32 != 0' \
    "non-zero float payload boundary"
require_pattern "$VALUE_FILE" 'entry\.reject_reason != MIR_C99_CONSTANT_REJECT_REASON_NONE' \
    "explicit reject entries appended"
require_pattern "$VALUE_FILE" 'value_plan\.diagnostic_code[[:space:]]*=' \
    "float payload reject updates diagnostic slot"
require_pattern "$VALUE_FILE" 'MIR_C99_VALUE_DIAG_UNSUPPORTED_FLOAT_CONSTANT_PAYLOAD' \
    "float payload reject emits diagnostic code"
require_pattern "$VALUE_FILE" 'value_plan\.reject_count = value_plan\.reject_count \+ 1usize' \
    "rejects counted"

require_pattern "$PLAN_FILE" 'MIR_GLOBAL_INIT_STRING' \
    "string initializer still owned by global-init plan"
require_pattern "$PLAN_FILE" 'MIR_CONST_KIND_STRING' \
    "string const kind validated in global-init plan"
require_pattern "$PLAN_FILE" 'mir_c99_global_initializer_string_metadata_valid' \
    "string metadata validator present"
require_pattern "$PLAN_FILE" 'global\.dedupe_id < 0 \|\| init_const\.dedupe_id < 0 \|\| init_const\.byte_count == 0usize' \
    "string dedupe/byte-count guard"
require_pattern "$PLAN_FILE" 'string_data:[[:space:]]*&byte' \
    "string payload stays on global-init entry"

require_pattern "$MATRIX_DOC" 'AST_FLOAT.*verify_mir_c99_constant_model\.sh' \
    "coverage matrix documents float constant-model guard"
require_pattern "$MATRIX_DOC" 'AST_STRING.*verify_mir_c99_constant_model\.sh' \
    "coverage matrix documents string global-init guard"
require_pattern "$MATRIX_DOC" 'AST_CHAR.*verify_mir_c99_constant_model\.sh' \
    "coverage matrix documents char/byte constant-model guard"

echo "OK: MIR-C99 constant model contract verified"
