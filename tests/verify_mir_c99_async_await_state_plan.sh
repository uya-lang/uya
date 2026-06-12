#!/usr/bin/env bash
#
# MIR-C99 await/bind state handling must be planned from PortableMIR async
# state/slot/result ops and async frame metadata.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG_FILE="$REPO_ROOT/src/codegen/mir_c99/cfg.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 async await state plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$CFG_FILE" "$DRIVER_FILE" "$MIR_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99AsyncAwaitStateTransition \
    async_await_transitions \
    async_await_transition_count \
    mir_c99_cfg_plan_append_async_await_transition \
    mir_c99_cfg_plan_build_async_await_transitions \
    mir_c99_cfg_async_await_transition_ptr; do
    require_pattern "$CFG_FILE" "$symbol" "async await transition symbol $symbol"
done

for symbol in \
    MIR_INST_OP_ASYNC_STATE_LOAD \
    MIR_INST_OP_ASYNC_STATE_STORE \
    MIR_INST_OP_ASYNC_AWAIT_CHILD_SLOT \
    MIR_INST_OP_ASYNC_RESULT_LOAD \
    MIR_ASYNC_FRAME_SLOT_STATE_TAG \
    MIR_ASYNC_FRAME_SLOT_RESULT \
    MIR_ASYNC_FRAME_SLOT_AWAIT_CHILD \
    MirAsyncFrameMeta \
    state_tag \
    result_slot_index \
    await_child_slot_index; do
    require_pattern "$CFG_FILE" "$symbol" "CFG consumes async await symbol $symbol"
    require_pattern "$MIR_FILE" "$symbol" "PortableMIR exposes async await symbol $symbol"
done

require_pattern "$CFG_FILE" 'module\.insts\.count' \
    "await transition plan scans MIR instructions"
require_pattern "$CFG_FILE" 'module\.async_frame_metas\.count' \
    "await transition plan resolves async frame metadata"
require_pattern "$CFG_FILE" 'inst\.op == MIR_INST_OP_ASYNC_STATE_LOAD' \
    "await transition plan handles state load"
require_pattern "$CFG_FILE" 'inst\.op == MIR_INST_OP_ASYNC_STATE_STORE' \
    "await transition plan handles state store"
require_pattern "$CFG_FILE" 'inst\.op == MIR_INST_OP_ASYNC_AWAIT_CHILD_SLOT' \
    "await transition plan handles await child slot"
require_pattern "$CFG_FILE" 'inst\.op == MIR_INST_OP_ASYNC_RESULT_LOAD' \
    "await transition plan handles result load"
require_pattern "$DRIVER_FILE" 'mir_c99_cfg_plan_build_async_await_transitions\(request\.module,[[:space:]]*cfg_plan\)' \
    "driver builds async await transition plan"
require_pattern "$TODO_FILE" 'await.*bind.*direct await.*loop await' \
    "todo tracks await state leaf"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CFG_FILE"; then
    echo "error: MIR-C99 async await state plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_async_await_state_plan.XXXXXX.uya)"
trap 'rm -f "$tmp"' EXIT
sed '/^use codegen\.mir_c99\./d' \
    "$REPO_ROOT/src/codegen/mir_c99/plan.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/types.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/names.uya" \
    "$CFG_FILE" \
    "$REPO_ROOT/src/codegen/mir_c99/unit_output.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/emitter.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/values.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/place_memory.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/calls.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya" \
    "$DRIVER_FILE" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 async await state plan verified"
