#!/usr/bin/env bash
#
# MIR-C99 vector/mask explicit reject/helper boundary verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALUES_FILE="$REPO_ROOT/src/codegen/mir_c99/values.uya"
TYPES_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 vector/mask explicit reject plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$VALUES_FILE" "$TYPES_FILE" "$DRIVER_FILE" "$MIR_FILE" "$VERIFIER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_EXPR_KIND_VECTOR_MASK_HELPER \
    MIR_C99_VALUE_DIAG_UNSUPPORTED_VECTOR_MASK_CAPABILITY \
    MIR_C99_EXPR_REJECT_REASON_VECTOR_MASK_CAPABILITY \
    portable_mir_inst_op_is_vector_mask \
    mir_c99_expression_is_explicit_reject \
    MIR_C99_EXPR_STATUS_REJECT \
    reject_count; do
    require_pattern "$VALUES_FILE" "$symbol" "vector/mask reject symbol $symbol"
done

require_pattern "$VALUES_FILE" 'portable_mir_inst_op_is_vector_mask\(inst\.op\)' \
    "vector/mask opcodes are classified before generic unsupported fallback"
require_pattern "$VALUES_FILE" 'entry\.reject_reason ==' \
    "vector/mask reject checks expression entry reason"
require_pattern "$VALUES_FILE" 'MIR_C99_EXPR_REJECT_REASON_VECTOR_MASK_CAPABILITY' \
    "vector/mask reject reason selected from expression entry"
require_pattern "$VALUES_FILE" 'MIR_C99_VALUE_DIAG_UNSUPPORTED_VECTOR_MASK_CAPABILITY' \
    "vector/mask reject exposes capability diagnostic"
require_pattern "$VALUES_FILE" 'semantic_vector_append\(&value_plan\.expressions' \
    "vector/mask reject entries are recorded in expression plan"
require_pattern "$TYPES_FILE" 'MIR_C99_C_TYPE_KIND_VECTOR_HELPER' \
    "vector types map to explicit helper type kind"
require_pattern "$TYPES_FILE" 'MIR_C99_C_TYPE_KIND_MASK_HELPER' \
    "mask types map to explicit helper type kind"
require_pattern "$DRIVER_FILE" 'mir_c99_value_plan_diagnostic_code\(value_plan\)' \
    "driver propagates value plan diagnostic"
require_pattern "$MIR_FILE" 'portable_mir_inst_op_is_vector_mask' \
    "PortableMIR exposes vector/mask opcode classifier"
require_pattern "$VERIFIER_FILE" 'MIR_VERIFY_ERR_INVALID_VECTOR_MASK' \
    "PortableMIR verifier validates vector/mask metadata"
require_pattern "$TODO_FILE" 'SIMD.*首版.*reject' \
    "todo records current SIMD oracle strategy"

tmp="$(mktemp /tmp/mir_c99_vector_mask_explicit_reject_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$TYPES_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/cfg.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$VALUES_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/calls.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 vector/mask explicit reject/helper plan verified"
