#!/usr/bin/env bash
#
# PortableMIR async frame metadata verifier.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
CONTRACT_FILE="$REPO_ROOT/src/lower/mir_contract.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
WHITEPAPER_FILE="$REPO_ROOT/docs/portable_mir_whitepaper.md"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: PortableMIR async frame missing evidence: $description" >&2
        exit 1
    fi
}

for file in "$MIR_FILE" "$CONTRACT_FILE" "$VERIFIER_FILE" "$WHITEPAPER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MIR_INST_OP_ASYNC_FRAME_ALLOC \
    MIR_INST_OP_ASYNC_FRAME_FREE \
    MIR_INST_OP_ASYNC_STATE_LOAD \
    MIR_INST_OP_ASYNC_STATE_STORE \
    MIR_INST_OP_ASYNC_AWAIT_CHILD_SLOT \
    MIR_INST_OP_ASYNC_POLL_CHILD \
    MIR_INST_OP_ASYNC_RESUME_EDGE \
    MIR_INST_OP_ASYNC_RESULT_LOAD \
    MIR_ASYNC_FRAME_SLOT_STATE_TAG \
    MIR_ASYNC_FRAME_SLOT_RESULT \
    MIR_ASYNC_FRAME_SLOT_AWAIT_CHILD \
    MIR_ASYNC_FRAME_SLOT_CAPTURED_LOCAL \
    MIR_RUNTIME_CAP_ASYNC_FRAME \
    MirAsyncFrameMeta \
    portable_mir_inst_op_is_async_frame; do
    require_pattern "$MIR_FILE" "$symbol" "MIR async frame symbol $symbol"
done

for symbol in \
    MIR_INST_OP_ASYNC_FRAME_ALLOC \
    MIR_INST_OP_ASYNC_FRAME_FREE \
    MIR_INST_OP_ASYNC_STATE_LOAD \
    MIR_INST_OP_ASYNC_STATE_STORE \
    MIR_INST_OP_ASYNC_AWAIT_CHILD_SLOT \
    MIR_INST_OP_ASYNC_POLL_CHILD \
    MIR_INST_OP_ASYNC_RESUME_EDGE \
    MIR_INST_OP_ASYNC_RESULT_LOAD \
    MIR_ASYNC_FRAME_SLOT_STATE_TAG \
    MIR_ASYNC_FRAME_SLOT_RESULT \
    MIR_ASYNC_FRAME_SLOT_AWAIT_CHILD \
    MIR_ASYNC_FRAME_SLOT_CAPTURED_LOCAL \
    MIR_RUNTIME_CAP_ASYNC_FRAME; do
    require_pattern "$CONTRACT_FILE" "$symbol" "contract async frame symbol $symbol"
done

require_pattern "$VERIFIER_FILE" 'portable_mir_verify_async_frame_inst' \
    "verifier has async frame helper"
require_pattern "$VERIFIER_FILE" 'MIR_RUNTIME_CAP_ASYNC_FRAME' \
    "verifier checks async frame runtime capability"
require_pattern "$WHITEPAPER_FILE" 'state tag、result slot、await child slot、captured locals' \
    "whitepaper records async frame slots"
require_pattern "$TODO_FILE" 'async frame metadata：state tag、result slot、await child slot、captured locals、poll/resume edge、frame allocation/free capability' \
    "todo records async frame metadata leaf"

echo "OK: PortableMIR async frame metadata verified"
