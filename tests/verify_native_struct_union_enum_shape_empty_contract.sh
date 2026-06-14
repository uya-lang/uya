#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_struct_union_enum_shape_empty()
# struct literal return 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_mir_c99_backend.md"
TODO_COMPLETED_DOC="$REPO_ROOT/docs/todo_mir_c99_backend_completed.md"
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

require_pattern_any() {
    local pattern="$1"
    local description="$2"
    shift 2
    local file
    for file in "$@"; do
        if grep -Eq "$pattern" "$file"; then
            return 0
        fi
    done
    echo "错误: $description" >&2
    printf '文件: %s\n' "$*" >&2
    exit 1
}

for file in "$SUBSET_DOC" "$TODO_DOC" "$TODO_COMPLETED_DOC" "$BUILD_DRIVER_SRC" \
    "$CORE_FILE" "$MIR_FILE" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern_any 'native_build_struct_union_enum_shape_empty\(\)' \
    "todo/归档缺少 native_build_struct_union_enum_shape_empty 合同任务" \
    "$TODO_DOC" "$TODO_COMPLETED_DOC"
require_pattern_any 'body-complete 合同' \
    "todo/归档缺少 native_build_struct_union_enum_shape_empty body-complete 合同意图" \
    "$TODO_DOC" "$TODO_COMPLETED_DOC"
require_pattern "$SUBSET_DOC" '^## `native_build_struct_union_enum_shape_empty\(\)` Body Complete Contract' \
    "subset doc 缺少 native_build_struct_union_enum_shape_empty 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_struct_union_enum_shape_empty .*reason=pending_core_body' \
    "subset doc 缺少当前 native_build_struct_union_enum_shape_empty pending frontier"
require_pattern "$SUBSET_DOC" 'struct_decl: null' \
    "subset doc 缺少 struct_decl null 字段"
require_pattern "$SUBSET_DOC" 'union_decl: null' \
    "subset doc 缺少 union_decl null 字段"
require_pattern "$SUBSET_DOC" 'match_decl: null' \
    "subset doc 缺少 match_decl null 字段"
require_pattern "$SUBSET_DOC" 'return_stmt: null' \
    "subset doc 缺少 return_stmt null 字段"
require_pattern "$SUBSET_DOC" 'struct_left_value: 0' \
    "subset doc 缺少 struct_left_value 0 字段"
require_pattern "$SUBSET_DOC" 'struct_right_value: 0' \
    "subset doc 缺少 struct_right_value 0 字段"
require_pattern "$SUBSET_DOC" 'union_value: 0' \
    "subset doc 缺少 union_value 0 字段"
require_pattern "$SUBSET_DOC" 'match_value: 0' \
    "subset doc 缺少 match_value 0 字段"
require_pattern "$SUBSET_DOC" 'return_value: 0' \
    "subset doc 缺少 return_value 0 字段"
require_pattern "$SUBSET_DOC" 'CORE_STMT_KIND_RETURN' \
    "subset doc 缺少 return CoreIR 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_struct_union_enum_shape_empty prefix_stmts=1 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'struct NativeBuildStructUnionEnumShape' \
    "源码缺少 NativeBuildStructUnionEnumShape struct"
require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_struct_union_enum_shape_empty\(\) NativeBuildStructUnionEnumShape' \
    "源码缺少 native_build_struct_union_enum_shape_empty helper"
require_pattern "$BUILD_DRIVER_SRC" 'return NativeBuildStructUnionEnumShape\{' \
    "源码缺少 NativeBuildStructUnionEnumShape return literal"
require_pattern "$BUILD_DRIVER_SRC" 'struct_decl: null' \
    "源码缺少 struct_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'union_decl: null' \
    "源码缺少 union_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'match_decl: null' \
    "源码缺少 match_decl null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_stmt: null' \
    "源码缺少 return_stmt null 字段"
require_pattern "$BUILD_DRIVER_SRC" 'struct_left_value: 0' \
    "源码缺少 struct_left_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'struct_right_value: 0' \
    "源码缺少 struct_right_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'union_value: 0' \
    "源码缺少 union_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'match_value: 0' \
    "源码缺少 match_value 0 字段"
require_pattern "$BUILD_DRIVER_SRC" 'return_value: 0' \
    "源码缺少 return_value 0 字段"
require_pattern "$CORE_FILE" 'CORE_STMT_KIND_RETURN' \
    "CoreIR 缺少 return statement kind"
require_pattern "$MIR_FILE" 'MIR_TERMINATOR_KIND_RETURN' \
    "PortableMIR 缺少 return terminator"
require_pattern "$STAGE1_TEST" 'verify_native_struct_union_enum_shape_empty_contract\.sh' \
    "stage1 未纳入 native_build_struct_union_enum_shape_empty 合同"

echo "verify_native_struct_union_enum_shape_empty_contract: ok"
