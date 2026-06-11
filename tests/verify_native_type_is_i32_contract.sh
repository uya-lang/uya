#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_type_is_i32(...)
# 3 statement helper 的 CoreBody/PortableMIR body-complete 合同。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBSET_DOC="$REPO_ROOT/docs/native_cmd_build_subset.md"
TODO_DOC="$REPO_ROOT/docs/todo_compiler_1s.md"
BUILD_DRIVER_SRC="$REPO_ROOT/src/build_compiler_driver.uya"
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

for file in "$SUBSET_DOC" "$TODO_DOC" "$BUILD_DRIVER_SRC" "$STAGE1_TEST"; do
    if [[ ! -f "$file" ]]; then
        echo "错误: 缺少 $file" >&2
        exit 1
    fi
done

require_pattern "$TODO_DOC" 'native_build_type_is_i32\(\.\.\.\)' \
    "todo 缺少 native_build_type_is_i32 合同任务"
require_pattern "$TODO_DOC" '3 statement body surface' \
    "todo 缺少 native_build_type_is_i32 3 statement 合同意图"
require_pattern "$SUBSET_DOC" '^## `native_build_type_is_i32\(\.\.\.\)` Body Complete Contract' \
    "subset doc 缺少 native_build_type_is_i32 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_type_is_i32 .*body_stmts=3 reason=pending_core_body' \
    "subset doc 缺少当前 native_build_type_is_i32 pending frontier"
require_pattern "$SUBSET_DOC" 'type_node == null \|\| type_node\.type != ASTNodeType\.AST_TYPE_NAMED \|\| type_node\.type_named_name == null' \
    "subset doc 缺少 null/type/name guard"
require_pattern "$SUBSET_DOC" 'str_equals\(type_node\.type_named_name, "i32" as \*byte\) != 0' \
    "subset doc 缺少 i32 str_equals branch"
require_pattern "$SUBSET_DOC" 'return 1' \
    "subset doc 缺少 success return"
require_pattern "$SUBSET_DOC" 'return 0' \
    "subset doc 缺少 fallback return"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_type_is_i32 prefix_stmts=3 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_type_is_i32\(type_node: &ASTNode\) i32' \
    "源码缺少 native_build_type_is_i32 helper"
require_pattern "$BUILD_DRIVER_SRC" 'type_node == null \|\| type_node\.type != ASTNodeType\.AST_TYPE_NAMED \|\| type_node\.type_named_name == null' \
    "源码缺少 null/type/name guard"
require_pattern "$BUILD_DRIVER_SRC" 'str_equals\(type_node\.type_named_name, "i32" as \*byte\) != 0' \
    "源码缺少 i32 str_equals branch"
require_pattern "$STAGE1_TEST" 'verify_native_type_is_i32_contract\.sh' \
    "stage1 未纳入 native_build_type_is_i32 合同"

echo "verify_native_type_is_i32_contract: ok"
