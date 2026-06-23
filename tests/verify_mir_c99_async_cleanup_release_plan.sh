#!/usr/bin/env bash
#
# MIR-C99 async cleanup/error/frame-release handling must be planned from
# PortableMIR cleanup/drop/error-union/async-frame-free ops.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG_FILE="$REPO_ROOT/src/codegen/mir_c99/cfg.uya"
DRIVER_FILE="$REPO_ROOT/src/codegen/mir_c99/driver.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
VERIFIER_FILE="$REPO_ROOT/src/lower/mir_verifier.uya"
TODO_FILE="$REPO_ROOT/docs/todo_mir_c99_backend.md"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "error: MIR-C99 async cleanup/release plan missing evidence: $description" >&2
        echo "file: $file" >&2
        exit 1
    fi
}

for file in "$CFG_FILE" "$DRIVER_FILE" "$MIR_FILE" "$VERIFIER_FILE" "$TODO_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "error: missing source: $file" >&2
        exit 1
    fi
done

for symbol in \
    MirC99AsyncCleanupReleasePlanEntry \
    async_cleanup_releases \
    async_cleanup_release_count \
    mir_c99_cfg_plan_append_async_cleanup_release \
    mir_c99_cfg_plan_build_async_cleanup_releases \
    mir_c99_cfg_async_cleanup_release_ptr; do
    require_pattern "$CFG_FILE" "$symbol" "async cleanup/release symbol $symbol"
done

for symbol in \
    MIR_INST_OP_ASYNC_FRAME_FREE \
    MIR_INST_OP_ASYNC_RESULT_LOAD \
    MIR_INST_OP_ERROR_UNION_OK \
    MIR_INST_OP_ERROR_UNION_ERR \
    MIR_INST_FLAG_ERROR_UNION_CHECKED \
    MIR_CLEANUP_ACTION_DEFER \
    MIR_CLEANUP_ACTION_ERRDEFER \
    MIR_CLEANUP_ACTION_DROP; do
    require_pattern "$CFG_FILE" "$symbol" "CFG consumes cleanup/release symbol $symbol"
    require_pattern "$MIR_FILE" "$symbol" "PortableMIR exposes cleanup/release symbol $symbol"
done

require_pattern "$CFG_FILE" 'portable_mir_inst_op_is_drop\(inst\.op\)' \
    "async cleanup plan reuses MIR drop classifier"
require_pattern "$CFG_FILE" 'inst\.op == MIR_INST_OP_ASYNC_FRAME_FREE' \
    "async cleanup plan handles frame free"
require_pattern "$CFG_FILE" 'inst\.op == MIR_INST_OP_ASYNC_RESULT_LOAD' \
    "async cleanup plan handles async result load"
require_pattern "$CFG_FILE" 'mir_c99_cfg_error_union_path_from_inst' \
    "async cleanup plan records error-union success/failure path"
require_pattern "$DRIVER_FILE" 'mir_c99_cfg_plan_build_async_cleanup_releases\(request\.module,[[:space:]]*cfg_plan\)' \
    "driver builds async cleanup/release plan"
require_pattern "$VERIFIER_FILE" 'MIR_INST_OP_ASYNC_FRAME_FREE' \
    "PortableMIR verifier validates async frame free"
require_pattern "$TODO_FILE" 'async error union return、cleanup edge、defer/errdefer 与 frame release' \
    "todo tracks async cleanup/release leaf"

if grep -Eiq 'codegen/c99|codegen\.c99|c99_codegen_generate|C99CodeGenerator|TypedProgram|LoweredProgram|ASTNode|TypeChecker' "$CFG_FILE"; then
    echo "error: MIR-C99 async cleanup/release plan must not use legacy C99 or pre-MIR structures" >&2
    exit 1
fi

echo "OK: MIR-C99 async cleanup/release plan verified"
