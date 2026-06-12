#!/usr/bin/env bash
#
# MIR-C99 async poll/resume state machine plan must consume PortableMIR async
# ops/metadata and lower to label/goto-shaped C control flow.

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
        echo "error: MIR-C99 async frame state-machine plan missing evidence: $description" >&2
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
    MirC99AsyncFrameStateEdge \
    async_state_edges \
    async_state_edge_count \
    mir_c99_cfg_plan_append_async_state_edge \
    mir_c99_cfg_plan_build_async_state_edges \
    mir_c99_cfg_emit_async_state_goto; do
    require_pattern "$CFG_FILE" "$symbol" "async state-machine symbol $symbol"
done

for symbol in \
    MIR_INST_OP_ASYNC_POLL_CHILD \
    MIR_INST_OP_ASYNC_RESUME_EDGE \
    MirAsyncFrameMeta \
    poll_block_id \
    resume_block_id; do
    require_pattern "$CFG_FILE" "$symbol" "CFG consumes PortableMIR async state symbol $symbol"
    require_pattern "$MIR_FILE" "$symbol" "PortableMIR exposes async state symbol $symbol"
done

require_pattern "$CFG_FILE" 'module\.insts\.count' \
    "state-machine plan scans MIR instructions"
require_pattern "$CFG_FILE" 'module\.async_frame_metas\.count' \
    "state-machine plan can resolve async frame metadata"
require_pattern "$CFG_FILE" 'inst\.op == MIR_INST_OP_ASYNC_POLL_CHILD' \
    "state-machine plan handles poll child op"
require_pattern "$CFG_FILE" 'inst\.op == MIR_INST_OP_ASYNC_RESUME_EDGE' \
    "state-machine plan handles resume edge op"
require_pattern "$CFG_FILE" 'goto bb' \
    "state-machine emit uses low-level goto labels"
require_pattern "$DRIVER_FILE" 'mir_c99_cfg_plan_build_async_state_edges\(request\.module,[[:space:]]*cfg_plan\)' \
    "driver builds async state-machine plan"
require_pattern "$TODO_FILE" 'poll/resume state machine 的低级 C label/goto' \
    "todo tracks poll/resume state-machine leaf"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CFG_FILE"; then
    echo "error: MIR-C99 async state-machine plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_async_frame_state_machine_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 async frame state-machine plan verified"
