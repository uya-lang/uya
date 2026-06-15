#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_const_slice_sum_shape_empty()
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

require_pattern "$SUBSET_DOC" '^## `native_build_const_slice_sum_shape_empty\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_const_slice_sum_shape_empty 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_const_slice_sum_shape_empty .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_const_slice_sum_shape_empty pending frontier"
require_pattern "$SUBSET_DOC" 'array_decl: null' \
    "subset doc 缺少 array_decl null 字段"
require_pattern "$SUBSET_DOC" 'slice_decl: null' \
    "subset doc 缺少 slice_decl null 字段"
require_pattern "$SUBSET_DOC" 'return_stmt: null' \
    "subset doc 缺少 return_stmt null 字段"
require_pattern "$SUBSET_DOC" 'add_expr: null' \
    "subset doc 缺少 add_expr null 字段"
require_pattern "$SUBSET_DOC" 'left_access: null' \
    "subset doc 缺少 left_access null 字段"
require_pattern "$SUBSET_DOC" 'right_access: null' \
    "subset doc 缺少 right_access null 字段"
require_pattern "$SUBSET_DOC" 'slice_start: 0' \
    "subset doc 缺少 slice_start 0 字段"
require_pattern "$SUBSET_DOC" 'slice_len: 0' \
    "subset doc 缺少 slice_len 0 字段"
require_pattern "$SUBSET_DOC" 'left_value: 0' \
    "subset doc 缺少 left_value 0 字段"
require_pattern "$SUBSET_DOC" 'right_value: 0' \
    "subset doc 缺少 right_value 0 字段"
require_pattern "$SUBSET_DOC" 'sum_value: 0' \
    "subset doc 缺少 sum_value 0 字段"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_const_slice_sum_shape_empty prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'struct NativeBuildConstSliceSumShape' \
    "源码缺少 NativeBuildConstSliceSumShape struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_const_slice_sum_shape_empty\(\) NativeBuildConstSliceSumShape' \
    "源码缺少 native_build_const_slice_sum_shape_empty helper"
require_pattern "$BUILD_DRIVER_SRC" 'return NativeBuildConstSliceSumShape\{' \
    "源码缺少 NativeBuildConstSliceSumShape return literal"
require_pattern "$BUILD_DRIVER_SRC" 'array_decl: null' \
    "源码缺少 array_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'slice_decl: null' \
    "源码缺少 slice_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_stmt: null' \
    "源码缺少 return_stmt null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'add_expr: null' \
    "源码缺少 add_expr null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'left_access: null' \
    "源码缺少 left_access null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'right_access: null' \
    "源码缺少 right_access null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'slice_start: 0' \
    "源码缺少 slice_start 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'slice_len: 0' \
    "源码缺少 slice_len 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'left_value: 0' \
    "源码缺少 left_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'right_value: 0' \
    "源码缺少 right_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'sum_value: 0' \
    "源码缺少 sum_value 0 字段"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_const_slice_sum_shape_empty_contract: ok"
