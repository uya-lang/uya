#!/usr/bin/env bash
#
# MIR-C99 async frame layout must be derived from PortableMIR async frame
# metadata, not from AST or legacy C99 async descriptors.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_FILE="$REPO_ROOT/src/codegen/mir_c99/plan.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 async frame layout plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$PLAN_FILE" "$DRIVER_FILE" "$MIR_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99AsyncFrameLayout \
    MirC99AsyncFrameSlotLayout \
    MIR_C99_REF_KIND_ASYNC_FRAME_LAYOUT \
    MIR_C99_REF_KIND_ASYNC_FRAME_SLOT \
    mir_c99_async_frame_layout_plan_build \
    mir_c99_async_frame_layout_plan_meta_ptr \
    mir_c99_async_frame_layout_plan_append_slot \
    async_frame_layouts \
    async_frame_slots; do
    require_pattern "$PLAN_FILE" "$symbol" "async frame layout symbol $symbol"
done

for symbol in \
    MIR_ASYNC_FRAME_SLOT_STATE_TAG \
    MIR_ASYNC_FRAME_SLOT_RESULT \
    MIR_ASYNC_FRAME_SLOT_AWAIT_CHILD \
    MIR_ASYNC_FRAME_SLOT_CAPTURED_LOCAL \
    MirAsyncFrameMeta \
    async_frame_metas; do
    require_pattern "$PLAN_FILE" "$symbol" "PortableMIR async metadata consumed in plan: $symbol"
    require_pattern "$MIR_FILE" "$symbol" "PortableMIR exposes async metadata: $symbol"
done

require_pattern "$PLAN_FILE" 'module\.async_frame_metas\.count' \
    "layout plan scans PortableMIR async metadata table"
require_pattern "$PLAN_FILE" 'meta\.slot_kind == MIR_ASYNC_FRAME_SLOT_STATE_TAG' \
    "layout plan records state tag slot"
require_pattern "$PLAN_FILE" 'meta\.slot_kind == MIR_ASYNC_FRAME_SLOT_RESULT' \
    "layout plan records result slot"
require_pattern "$PLAN_FILE" 'meta\.slot_kind == MIR_ASYNC_FRAME_SLOT_AWAIT_CHILD' \
    "layout plan records await child slot"
require_pattern "$PLAN_FILE" 'meta\.slot_kind == MIR_ASYNC_FRAME_SLOT_CAPTURED_LOCAL' \
    "layout plan records captured local slot"
require_pattern "$PLAN_FILE" 'mir_c99_plan_append_ref\(plan,[[:space:]]*MIR_C99_REF_KIND_ASYNC_FRAME_LAYOUT' \
    "layout refs are appended to MIR-C99 plan"
require_pattern "$PLAN_FILE" 'mir_c99_unit_append_ref\(unit,[[:space:]]*MIR_C99_REF_KIND_ASYNC_FRAME_LAYOUT' \
    "layout refs are appended to MIR-C99 unit"
require_pattern "$DRIVER_FILE" 'mir_c99_async_frame_layout_plan_build\(request\.module,[[:space:]]*plan,[[:space:]]*primary_unit\)' \
    "driver builds async frame layout plan"
require_pattern "$TODO_FILE" 'async frame struct layout、state tag、result slot、await child slot 和 captured locals' \
    "todo tracks async frame layout leaf"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$PLAN_FILE"; then
    echo "error: MIR-C99 async frame layout plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_async_frame_layout_plan.XXXXXX.uya)"
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
    "$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya" \
    "$REPO_ROOT/src/codegen/mir_c99/driver.uya" >"$tmp"
"$REPO_ROOT/bin/uya" check "$tmp" >/dev/null

echo "OK: MIR-C99 async frame layout plan verified"
