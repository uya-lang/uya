#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_pointer_deref_shape_empty()
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

require_pattern "$SUBSET_DOC" '^## `native_build_pointer_deref_shape_empty\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_pointer_deref_shape_empty 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_pointer_deref_shape_empty .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_pointer_deref_shape_empty pending frontier"
require_pattern "$SUBSET_DOC" 'value_decl: null' \
    "subset doc 缺少 value_decl null 字段"
require_pattern "$SUBSET_DOC" 'pointer_decl: null' \
    "subset doc 缺少 pointer_decl null 字段"
require_pattern "$SUBSET_DOC" 'return_stmt: null' \
    "subset doc 缺少 return_stmt null 字段"
require_pattern "$SUBSET_DOC" 'address_expr: null' \
    "subset doc 缺少 address_expr null 字段"
require_pattern "$SUBSET_DOC" 'deref_expr: null' \
    "subset doc 缺少 deref_expr null 字段"
require_pattern "$SUBSET_DOC" 'value: 0' \
    "subset doc 缺少 value 0 字段"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_pointer_deref_shape_empty prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'struct NativeBuildPointerDerefShape' \
    "源码缺少 NativeBuildPointerDerefShape struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_pointer_deref_shape_empty\(\) NativeBuildPointerDerefShape' \
    "源码缺少 native_build_pointer_deref_shape_empty helper"
require_pattern "$BUILD_DRIVER_SRC" 'return NativeBuildPointerDerefShape\{' \
    "源码缺少 NativeBuildPointerDerefShape return literal"
require_pattern "$BUILD_DRIVER_SRC" 'value_decl: null' \
    "源码缺少 value_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'pointer_decl: null' \
    "源码缺少 pointer_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_stmt: null' \
    "源码缺少 return_stmt null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'address_expr: null' \
    "源码缺少 address_expr null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'deref_expr: null' \
    "源码缺少 deref_expr null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'value: 0' \
    "源码缺少 value 0 字段"
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

echo "verify_native_pointer_deref_shape_empty_contract: ok"
