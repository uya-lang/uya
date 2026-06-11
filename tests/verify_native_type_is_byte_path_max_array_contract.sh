#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_type_is_byte_path_max_array(...)
# 2 statement helper 的 CoreBody/PortableMIR body-complete 合同。

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

require_pattern "$TODO_DOC" 'native_build_type_is_byte_path_max_array\(\.\.\.\)' \
    "todo 缺少 native_build_type_is_byte_path_max_array 合同任务"
require_pattern "$SUBSET_DOC" '^## `native_build_type_is_byte_path_max_array\(\.\.\.\)` Body Complete Contract' \
    "subset doc 缺少 native_build_type_is_byte_path_max_array 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_type_is_byte_path_max_array .*body_stmts=2 reason=pending_core_body' \
    "subset doc 缺少当前 native_build_type_is_byte_path_max_array pending frontier"
require_pattern "$SUBSET_DOC" 'type_node == null \|\| type_node\.type != ASTNodeType\.AST_TYPE_ARRAY' \
    "subset doc 缺少 array guard"
require_pattern "$SUBSET_DOC" 'native_build_type_is_byte\(type_node\.type_array_element_type\) == 0' \
    "subset doc 缺少 byte element helper-call guard"
require_pattern "$SUBSET_DOC" 'type_node\.type_array_size_expr\.type != ASTNodeType\.AST_IDENTIFIER' \
    "subset doc 缺少 PATH_MAX identifier type guard"
require_pattern "$SUBSET_DOC" 'type_node\.type_array_size_expr\.identifier_name == null' \
    "subset doc 缺少 PATH_MAX identifier name guard"
require_pattern "$SUBSET_DOC" 'str_equals\(type_node\.type_array_size_expr\.identifier_name as \*byte,' \
    "subset doc 缺少 PATH_MAX str_equals guard"
require_pattern "$SUBSET_DOC" '"PATH_MAX" as \*byte\) == 0' \
    "subset doc 缺少 PATH_MAX literal guard"
require_pattern "$SUBSET_DOC" 'return 1;' \
    "subset doc 缺少 tail return 1"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_type_is_byte_path_max_array prefix_stmts=2 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"
require_pattern "$SUBSET_DOC" 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[0-9]+ core_bodies=39 pending_bodies=[0-9]+' \
    "subset doc 缺少 native_build_type_is_byte_path_max_array 迁入后的 CoreBody 计数"
require_pattern "$SUBSET_DOC" 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[0-9]+ mir_body_functions=38' \
    "subset doc 缺少 native_build_type_is_byte_path_max_array 迁入后的 MIR body 计数"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_decl_is_noarg_i32_fn .*body_stmts=3 reason=pending_core_body' \
    "subset doc 缺少 native_build_type_is_byte_path_max_array 迁入后的下一 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_type_is_byte_path_max_array\(type_node: &ASTNode\) i32' \
    "源码缺少 native_build_type_is_byte_path_max_array helper"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_type_is_byte\(type_node\.type_array_element_type\) == 0' \
    "源码缺少 byte element helper-call guard"
require_pattern "$BUILD_DRIVER_SRC" 'str_equals\(type_node\.type_array_size_expr\.identifier_name as \*byte,' \
    "源码缺少 PATH_MAX str_equals guard"
require_pattern "$STAGE1_TEST" 'verify_native_type_is_byte_path_max_array_contract\.sh' \
    "stage1 未纳入 native_build_type_is_byte_path_max_array 合同"

echo "verify_native_type_is_byte_path_max_array_contract: ok"
