#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_simd_vector_mask_shape_empty()
# struct literal return 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
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

require_pattern "$TODO_DOC" 'native_build_simd_vector_mask_shape_empty\(\)' \
    "todo 缺少 native_build_simd_vector_mask_shape_empty 合同任务"
require_pattern "$TODO_DOC" 'body-complete 合同' \
    "todo 缺少 native_build_simd_vector_mask_shape_empty body-complete 合同意图"
require_pattern "$SUBSET_DOC" '^## `native_build_simd_vector_mask_shape_empty\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_simd_vector_mask_shape_empty 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_simd_vector_mask_shape_empty .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_simd_vector_mask_shape_empty pending frontier"
require_pattern "$SUBSET_DOC" 'left_decl: null' \
    "subset doc 缺少 left_decl null 字段"
require_pattern "$SUBSET_DOC" 'right_decl: null' \
    "subset doc 缺少 right_decl null 字段"
require_pattern "$SUBSET_DOC" 'mask_decl: null' \
    "subset doc 缺少 mask_decl null 字段"
require_pattern "$SUBSET_DOC" 'selected_decl: null' \
    "subset doc 缺少 selected_decl null 字段"
require_pattern "$SUBSET_DOC" 'return_stmt: null' \
    "subset doc 缺少 return_stmt null 字段"
require_pattern "$SUBSET_DOC" 'lanes: 0' \
    "subset doc 缺少 lanes 0 字段"
require_pattern "$SUBSET_DOC" 'left_value: 0' \
    "subset doc 缺少 left_value 0 字段"
require_pattern "$SUBSET_DOC" 'right_value: 0' \
    "subset doc 缺少 right_value 0 字段"
require_pattern "$SUBSET_DOC" 'mask_truth: 0' \
    "subset doc 缺少 mask_truth 0 字段"
require_pattern "$SUBSET_DOC" 'selected_value: 0' \
    "subset doc 缺少 selected_value 0 字段"
require_pattern "$SUBSET_DOC" 'return_value: 0' \
    "subset doc 缺少 return_value 0 字段"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_simd_vector_mask_shape_empty prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'struct NativeBuildSimdVectorMaskShape' \
    "源码缺少 NativeBuildSimdVectorMaskShape struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_simd_vector_mask_shape_empty\(\) NativeBuildSimdVectorMaskShape' \
    "源码缺少 native_build_simd_vector_mask_shape_empty helper"
require_pattern "$BUILD_DRIVER_SRC" 'return NativeBuildSimdVectorMaskShape\{' \
    "源码缺少 NativeBuildSimdVectorMaskShape return literal"
require_pattern "$BUILD_DRIVER_SRC" 'left_decl: null' \
    "源码缺少 left_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'right_decl: null' \
    "源码缺少 right_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'mask_decl: null' \
    "源码缺少 mask_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'selected_decl: null' \
    "源码缺少 selected_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_stmt: null' \
    "源码缺少 return_stmt null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'lanes: 0' \
    "源码缺少 lanes 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'left_value: 0' \
    "源码缺少 left_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'right_value: 0' \
    "源码缺少 right_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'mask_truth: 0' \
    "源码缺少 mask_truth 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'selected_value: 0' \
    "源码缺少 selected_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_value: 0' \
    "源码缺少 return_value 0 字段"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$STAGE1_TEST" 'verify_native_simd_vector_mask_shape_empty_contract\.sh' \
    "stage1 未纳入 native_build_simd_vector_mask_shape_empty 合同"

echo "verify_native_simd_vector_mask_shape_empty_contract: ok"
