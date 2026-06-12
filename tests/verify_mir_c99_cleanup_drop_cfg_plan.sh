#!/usr/bin/env bash
#
# MIR-C99 cleanup/drop CFG plan verifier.

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
        echo "error: MIR-C99 cleanup/drop CFG plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -Eiq "$pattern" "$file"; then
        echo "error: MIR-C99 cleanup/drop CFG plan found forbidden dependency: $description" >&2
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
    MIR_C99_CFG_DROP_STATUS_PLANNED \
    MIR_C99_CFG_DROP_FLAG_CLEANUP_EDGE \
    MirC99CleanupDropPlanEntry \
    cleanup_drops \
    cleanup_drop_count \
    mir_c99_cfg_plan_build_cleanup_drops \
    mir_c99_cfg_plan_append_cleanup_drop; do
    require_pattern "$CFG_FILE" "$symbol" "cleanup/drop CFG symbol $symbol"
done

require_pattern "$CFG_FILE" 'portable_mir_inst_op_is_drop\(inst\.op\)' \
    "CFG plan recognizes only MIR drop opcodes"
require_pattern "$CFG_FILE" 'inst\.op[[:space:]]*==[[:space:]]MIR_INST_OP_DROP_VALUE' \
    "CFG plan records DROP_VALUE"
require_pattern "$CFG_FILE" 'inst\.op[[:space:]]*==[[:space:]]MIR_INST_OP_DROP_IN_PLACE' \
    "CFG plan records DROP_IN_PLACE"
require_pattern "$CFG_FILE" 'block\.flags[[:space:]]*&[[:space:]]MIR_BLOCK_FLAG_CLEANUP' \
    "CFG plan requires MIR cleanup block flag"
require_pattern "$CFG_FILE" 'MIR_CLEANUP_ACTION_DEFER' \
    "CFG plan preserves defer cleanup action"
require_pattern "$CFG_FILE" 'MIR_CLEANUP_ACTION_ERRDEFER' \
    "CFG plan preserves errdefer cleanup action"
require_pattern "$CFG_FILE" 'MIR_CLEANUP_ACTION_LEXICAL_DROP' \
    "CFG plan preserves lexical drop cleanup action"
require_pattern "$DRIVER_FILE" 'mir_c99_cfg_plan_build_cleanup_drops' \
    "driver builds cleanup/drop plan from MIR"
require_pattern "$MIR_FILE" 'portable_mir_inst_op_is_drop' \
    "PortableMIR exposes drop opcode classifier"
require_pattern "$VERIFIER_FILE" 'portable_mir_verify_drop_inst' \
    "PortableMIR verifier validates drop instructions"

reject_pattern "$CFG_FILE" 'ASTNode|AST_DEFER|AST_ERRDEFER|defer_stmt|errdefer_stmt|lexical_scope|TypedProgram|LoweredProgram|TypeChecker|C99CodeGenerator' \
    "pre-MIR defer/errdefer/drop structures in MIR-C99 CFG"
reject_pattern "$DRIVER_FILE" 'ASTNode|AST_DEFER|AST_ERRDEFER|defer_stmt|errdefer_stmt|lexical_scope|TypedProgram|LoweredProgram|TypeChecker|C99CodeGenerator' \
    "pre-MIR defer/errdefer/drop structures in MIR-C99 driver"

tmp="$(mktemp /tmp/mir_c99_cleanup_drop_cfg_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 cleanup/drop CFG plan verified"
