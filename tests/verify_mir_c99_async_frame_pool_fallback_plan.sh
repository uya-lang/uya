#!/usr/bin/env bash
#
# MIR-C99 async frame pool and heap-fallback policy must be represented in the
# runtime helper plan from the verified target backend request.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_FILE="$REPO_ROOT/src/codegen/mir_c99/runtime_helpers.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
BACKEND_FILE="$REPO_ROOT/src/lower/mir_backend.uya"
ASYNC_FRAME_FILE="$REPO_ROOT/lib/std/async_frame.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 async frame pool fallback plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$HELPER_FILE" "$DRIVER_FILE" "$BACKEND_FILE" "$ASYNC_FRAME_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99AsyncFramePoolPlan \
    async_frame_pool \
    async_frame_heap_fallback_enabled \
    async_frame_stack_limit \
    mir_c99_runtime_helper_plan_async_frame_pool \
    MIR_C99_ASYNC_FRAME_POOL_DEFAULT_STACK_LIMIT; do
    require_pattern "$HELPER_FILE" "$symbol" "runtime helper pool symbol $symbol"
done

require_pattern "$BACKEND_FILE" 'MIR_TARGET_BACKEND_FLAG_ASYNC_FRAME_HEAP_FALLBACK' \
    "backend request exposes async-frame heap fallback flag"
require_pattern "$HELPER_FILE" 'request\.flags[[:space:]]*&[[:space:]]MIR_TARGET_BACKEND_FLAG_ASYNC_FRAME_HEAP_FALLBACK' \
    "pool plan consumes backend request heap fallback flag"
require_pattern "$HELPER_FILE" 'module\.async_frame_metas\.count' \
    "pool plan inspects PortableMIR async frame metadata"
require_pattern "$HELPER_FILE" 'portable_mir_inst_op_is_async_frame' \
    "pool plan tracks async frame helper refs"
require_pattern "$DRIVER_FILE" 'mir_c99_runtime_helper_plan_build\(request,' \
    "driver passes full backend request to runtime helper plan"
require_pattern "$ASYNC_FRAME_FILE" '_uya_async_frame_heap_fallback' \
    "runtime library exposes generated heap fallback switch"
require_pattern "$TODO_FILE" 'async frame pool 和 `--async-frame-heap=on` fallback' \
    "todo tracks async frame pool/fallback leaf"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$HELPER_FILE"; then
    echo "error: MIR-C99 async frame pool plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

tmp="$(mktemp /tmp/mir_c99_async_frame_pool_fallback_plan.XXXXXX.uya)"
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

echo "OK: MIR-C99 async frame pool/fallback plan verified"
