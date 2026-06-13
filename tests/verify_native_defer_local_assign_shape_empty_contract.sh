#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_defer_local_assign_shape_empty()
# struct literal return 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_mir_c99_backend.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
CORE_FILE="$REPO_ROOT/src/lower/core.uya"
MIR_FILE="$REPO_ROOT/src/lower/mir.uya"
STAGE1_TEST="$REPO_ROOT/tests/verify_native_cmd_build_stage1.sh"

require_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "错误: $description" >&2
        echo "文件: $file" >&2
        exit 1
    fi
}

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$CORE_FILE" "$MIR_FILE" \
    "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" 'native_build_defer_local_assign_shape_empty\(\)' \
    "todo 缺少 native_build_defer_local_assign_shape_empty 合同任务"
require_pattern "$TODO_DOC" 'body-complete 合同' \
    "todo 缺少 native_build_defer_local_assign_shape_empty body-complete 合同意图"
require_pattern "$SUBSET_DOC" '^## `native_build_defer_local_assign_shape_empty\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_defer_local_assign_shape_empty 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_defer_local_assign_shape_empty .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_defer_local_assign_shape_empty pending frontier"
require_pattern "$SUBSET_DOC" 'local_decl: null' \
    "subset doc 缺少 local_decl null 字段"
require_pattern "$SUBSET_DOC" 'defer_stmt: null' \
    "subset doc 缺少 defer_stmt null 字段"
require_pattern "$SUBSET_DOC" 'assign_stmt: null' \
    "subset doc 缺少 assign_stmt null 字段"
require_pattern "$SUBSET_DOC" 'return_stmt: null' \
    "subset doc 缺少 return_stmt null 字段"
require_pattern "$SUBSET_DOC" 'initial_value: 0' \
    "subset doc 缺少 initial_value 0 字段"
require_pattern "$SUBSET_DOC" 'deferred_value: 0' \
    "subset doc 缺少 deferred_value 0 字段"
require_pattern "$SUBSET_DOC" 'return_value: 0' \
    "subset doc 缺少 return_value 0 字段"
require_pattern "$SUBSET_DOC" 'return_is_local_ref: 0' \
    "subset doc 缺少 return_is_local_ref 0 字段"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_defer_local_assign_shape_empty prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'struct NativeBuildDeferLocalAssignShape' \
    "源码缺少 NativeBuildDeferLocalAssignShape struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_defer_local_assign_shape_empty\(\) NativeBuildDeferLocalAssignShape' \
    "源码缺少 native_build_defer_local_assign_shape_empty helper"
require_pattern "$BUILD_DRIVER_SRC" 'return NativeBuildDeferLocalAssignShape\{' \
    "源码缺少 NativeBuildDeferLocalAssignShape return literal"
require_pattern "$BUILD_DRIVER_SRC" 'local_decl: null' \
    "源码缺少 local_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'defer_stmt: null' \
    "源码缺少 defer_stmt null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'assign_stmt: null' \
    "源码缺少 assign_stmt null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_stmt: null' \
    "源码缺少 return_stmt null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'initial_value: 0' \
    "源码缺少 initial_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'deferred_value: 0' \
    "源码缺少 deferred_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_value: 0' \
    "源码缺少 return_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_is_local_ref: 0' \
    "源码缺少 return_is_local_ref 0 字段"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$STAGE1_TEST" 'verify_native_defer_local_assign_shape_empty_contract\.sh' \
    "stage1 未纳入 native_build_defer_local_assign_shape_empty 合同"

echo "verify_native_defer_local_assign_shape_empty_contract: ok"
