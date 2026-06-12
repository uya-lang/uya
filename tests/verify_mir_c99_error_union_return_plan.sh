#!/usr/bin/env bash
#
# MIR-C99 error-union success/fallback return plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG_FILE="$REPO_ROOT/src/codegen/mir_c99/cfg.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 error-union return plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eiq "$pattern" "$file"; then
        echo "error: MIR-C99 error-union return plan found forbidden dependency: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$CFG_FILE" "$DRIVER_FILE" "$MIR_FILE" "$VERIFIER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_C99_CFG_ERROR_UNION_RETURN_STATUS_PLANNED \
    MIR_C99_CFG_ERROR_UNION_RETURN_FLAG_CHECKED \
    MirC99ErrorUnionReturnPlanEntry \
    error_union_returns \
    error_union_return_count \
    mir_c99_cfg_plan_build_error_union_returns \
    mir_c99_cfg_plan_append_error_union_return; do
    require_pattern "$CFG_FILE" "$symbol" "error-union return CFG symbol $symbol"
done

require_pattern "$CFG_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "CFG plan consumes return terminators"
require_pattern "$CFG_FILE" 'return_operand\.value_id' \
    "CFG plan uses MIR return operand value"
require_pattern "$CFG_FILE" 'defining_inst_id' \
    "CFG plan follows MIR value defining instruction"
require_pattern "$CFG_FILE" 'portable_mir_inst_op_is_error_union\(inst\.op\)' \
    "CFG plan recognizes MIR error-union opcodes"
require_pattern "$CFG_FILE" 'MIR_INST_OP_ERROR_UNION_OK' \
    "CFG plan records success construction"
require_pattern "$CFG_FILE" 'MIR_INST_OP_ERROR_UNION_ERR' \
    "CFG plan records fallback/error construction"
require_pattern "$CFG_FILE" 'MIR_INST_OP_ERROR_UNION_PAYLOAD' \
    "CFG plan records checked success payload"
require_pattern "$CFG_FILE" 'MIR_INST_OP_ERROR_UNION_ERROR' \
    "CFG plan records checked fallback error"
require_pattern "$CFG_FILE" 'MIR_ERROR_UNION_PATH_SUCCESS' \
    "CFG plan labels success path"
require_pattern "$CFG_FILE" 'MIR_ERROR_UNION_PATH_FAILURE' \
    "CFG plan labels fallback path"
require_pattern "$CFG_FILE" 'MIR_INST_FLAG_ERROR_UNION_CHECKED' \
    "CFG plan preserves checked extraction flag"
require_pattern "$DRIVER_FILE" 'mir_c99_cfg_plan_build_error_union_returns' \
    "driver builds error-union return plan from MIR"
require_pattern "$MIR_FILE" 'portable_mir_inst_op_is_error_union' \
    "PortableMIR exposes error-union opcode classifier"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_error_union_inst' \
    "PortableMIR verifier validates error-union instructions"

reject_pattern "$CFG_FILE" 'ASTNode|AST_TRY|AST_CATCH|try_expr|catch_expr|TypedProgram|LoweredProgram|TypeChecker|C99CodeGenerator' \
    "pre-MIR try/catch structures in MIR-C99 CFG"
reject_pattern "$DRIVER_FILE" 'ASTNode|AST_TRY|AST_CATCH|try_expr|catch_expr|TypedProgram|LoweredProgram|TypeChecker|C99CodeGenerator' \
    "pre-MIR try/catch structures in MIR-C99 driver"

tmp="$(mktemp /tmp/mir_c99_error_union_return_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$CFG_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/calls.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 error-union success/fallback return plan verified"
