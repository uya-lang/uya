#!/usr/bin/env bash
#
# MIR-C99 cleanup/error CFG boundary verifier.

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
        echo "error: MIR-C99 cleanup/error CFG boundary missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eiq "$pattern" "$file"; then
        echo "error: MIR-C99 cleanup/error CFG boundary found forbidden dependency: $description" >&2
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
    MIR_C99_CFG_FUNCTION_FLAG_CLEANUP_ERROR \
    MIR_C99_CFG_TERMINATOR_FLAG_ERROR_CFG \
    cleanup_error_function_count \
    cleanup_error_terminator_count \
    MIR_CLEANUP_MODEL_ERROR \
    MIR_BLOCK_FLAG_CLEANUP; do
    require_pattern "$CFG_FILE" "$symbol" "cleanup/error CFG symbol $symbol"
done

require_pattern "$CFG_FILE" 'function\.cleanup_model[[:space:]]*&[[:space:]]MIR_CLEANUP_MODEL_ERROR' \
    "CFG plan reads MIR cleanup model, not AST try/catch"
require_pattern "$CFG_FILE" 'block\.flags[[:space:]]*&[[:space:]]MIR_BLOCK_FLAG_CLEANUP' \
    "CFG plan records MIR cleanup blocks"
require_pattern "$CFG_FILE" 'MIR_TERMINATOR_KIND_COND_BR' \
    "try/catch lowered branch is consumed as COND_BR"
require_pattern "$CFG_FILE" 'mir_c99_cfg_successor_ptr' \
    "CFG plan consumes MIR successors"
require_pattern "$CFG_FILE" 'mir_c99_cfg_operand_ptr' \
    "CFG plan consumes MIR operands"
require_pattern "$DRIVER_FILE" 'mir_c99_cfg_plan_build_functions' \
    "driver builds MIR CFG function plan"
require_pattern "$DRIVER_FILE" 'mir_c99_cfg_plan_build_terminators' \
    "driver builds MIR CFG terminator plan"
require_pattern "$MIR_FILE" 'MIR_CLEANUP_MODEL_ERROR' \
    "PortableMIR exposes cleanup error model"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_cleanup_model_known' \
    "PortableMIR verifier validates cleanup model"

reject_pattern "$CFG_FILE" 'ASTNode|AST_TRY|AST_CATCH|try_expr|catch_expr|TypedProgram|LoweredProgram|TypeChecker|C99CodeGenerator' \
    "pre-MIR try/catch structures in MIR-C99 CFG"
reject_pattern "$DRIVER_FILE" 'ASTNode|AST_TRY|AST_CATCH|try_expr|catch_expr|TypedProgram|LoweredProgram|TypeChecker|C99CodeGenerator' \
    "pre-MIR try/catch structures in MIR-C99 driver"

tmp="$(mktemp /tmp/mir_c99_cleanup_error_cfg_boundary.XXXXXX.uya)"
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

echo "OK: MIR-C99 cleanup/error CFG boundary verified"
