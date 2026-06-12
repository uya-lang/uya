#!/usr/bin/env bash
#
# MIR-C99 async frame runtime helper plan verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_FILE="$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 async frame runtime helper plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$HELPER_FILE" "$DRIVER_FILE" "$MIR_FILE" "$VERIFIER_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_RUNTIME_CAP_ASYNC_FRAME \
    mir_c99_runtime_helper_plan_async_frames \
    portable_mir_inst_op_is_async_frame \
    mir_c99_runtime_helper_plan_build; do
    require_pattern "$HELPER_FILE" "$symbol" "async frame helper symbol $symbol"
done

for symbol in \
    MIR_INST_OP_ASYNC_FRAME_ALLOC \
    MIR_INST_OP_ASYNC_FRAME_FREE \
    MIR_INST_OP_ASYNC_AWAIT_CHILD_SLOT \
    MIR_INST_OP_ASYNC_POLL_CHILD \
    MIR_INST_OP_ASYNC_RESUME_EDGE; do
    require_pattern "$MIR_FILE" "$symbol" "PortableMIR async frame opcode $symbol"
    require_pattern "$VERIFIER_FILE" "$symbol" "verifier async frame opcode $symbol"
done

require_pattern "$HELPER_FILE" 'module\.insts\.count' \
    "async helper plan scans MIR instructions"
require_pattern "$HELPER_FILE" 'inst\.runtime_capability_mask[[:space:]]*&[[:space:]]MIR_RUNTIME_CAP_ASYNC_FRAME' \
    "async helper plan checks per-instruction async frame capability"
require_pattern "$HELPER_FILE" 'portable_mir_target_profile_supports_runtime_capability' \
    "async helper plan checks target async frame capability"
require_pattern "$HELPER_FILE" 'mir_c99_plan_append_ref\(mir_plan,[[:space:]]*MIR_C99_REF_KIND_HELPER' \
    "async frame refs appended to program plan from opcode and inst id"
require_pattern "$HELPER_FILE" 'mir_c99_unit_append_ref\(unit,[[:space:]]*MIR_C99_REF_KIND_HELPER' \
    "async frame refs appended to unit plan from opcode and inst id"
require_pattern "$HELPER_FILE" 'inst\.op,[[:space:]]*inst\.inst_id' \
    "async frame append refs use opcode and instruction id"
require_pattern "$DRIVER_FILE" 'mir_c99_runtime_helper_plan_build' \
    "driver builds runtime helper plan"
require_pattern "$MIR_FILE" 'portable_mir_inst_op_is_async_frame' \
    "PortableMIR exposes async frame opcode classifier"
require_pattern "$VERIFIER_FILE" 'MIR_RUNTIME_CAP_ASYNC_FRAME' \
    "PortableMIR verifier checks async frame capability"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$HELPER_FILE"; then
    echo "error: MIR-C99 runtime helpers must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_runtime_async_frame_helper_plan.XXXXXX.uya)"
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
    "$HELPER_FILE" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 async frame runtime helper plan verified"
