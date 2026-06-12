#!/usr/bin/env bash
#
# MIR-C99 atomic explicit reject/helper boundary verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALUES_FILE="$REPO_ROOT/src/codegen/mir_c99/values.uya"
TYPES_FILE="$REPO_ROOT/src/codegen/mir_c99/types.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 atomic explicit reject plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$VALUES_FILE" "$TYPES_FILE" "$DRIVER_FILE" "$MIR_FILE" "$VERIFIER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_EXPR_KIND_ATOMIC_HELPER \
    portable_mir_inst_op_is_atomic \
    mir_c99_expression_is_explicit_reject \
    MIR_C99_EXPR_STATUS_REJECT \
    reject_count; do
    require_pattern "$VALUES_FILE" "$symbol" "atomic expression reject symbol $symbol"
done

require_pattern "$VALUES_FILE" 'portable_mir_inst_op_is_atomic\(inst\.op\)' \
    "atomic opcodes are classified before generic unsupported fallback"
require_pattern "$VALUES_FILE" 'semantic_vector_append\(&value_plan\.expressions' \
    "atomic reject entries are recorded in the expression plan"
require_pattern "$VALUES_FILE" 'value_plan\.reject_count = value_plan\.reject_count \+ 1usize' \
    "atomic reject increments value plan reject count"
require_pattern "$VALUES_FILE" 'return -1' \
    "atomic reject fails the MIR-C99 value plan instead of silently falling back"
require_pattern "$TYPES_FILE" 'MIR_C99_C_TYPE_KIND_ATOMIC_HELPER' \
    "atomic types map to explicit helper type kind"
require_pattern "$DRIVER_FILE" 'mir_c99_value_plan_build_expressions' \
    "driver consumes expression reject status"
require_pattern "$MIR_FILE" 'portable_mir_inst_op_is_atomic' \
    "PortableMIR exposes atomic opcode classifier"
require_pattern "$VERIFIER_FILE" 'MIR_VERIFY_ERR_INVALID_ATOMIC' \
    "PortableMIR verifier validates atomic metadata"

tmp="$(mktemp /tmp/mir_c99_atomic_explicit_reject_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 atomic explicit reject/helper plan verified"
