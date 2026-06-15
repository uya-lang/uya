#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_type_is_byte_ptr(...)
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
require_pattern "$SUBSET_DOC" '^## `native_build_type_is_byte_ptr\(\.\.\.\)` Body Complete Contract' \
    "subset doc 缺少 native_build_type_is_byte_ptr 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_type_is_byte_ptr .*body_stmts=2 reason=pending_core_body' \
    "subset doc 缺少当前 native_build_type_is_byte_ptr pending frontier"
require_pattern "$SUBSET_DOC" 'type_node == null \|\| type_node\.type != ASTNodeType\.AST_TYPE_POINTER' \
    "subset doc 缺少 pointer guard"
require_pattern "$SUBSET_DOC" 'return native_build_type_is_byte\(type_node\.type_pointer_pointed_type\);' \
    "subset doc 缺少 byte pointed-type helper-call return"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_type_is_byte_ptr prefix_stmts=2 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"
require_pattern "$SUBSET_DOC" 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[0-9]+ core_bodies=35 pending_bodies=[0-9]+' \
    "subset doc 缺少 native_build_type_is_byte_ptr 迁入后的 CoreBody 计数"
require_pattern "$SUBSET_DOC" 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[0-9]+ mir_body_functions=34' \
    "subset doc 缺少 native_build_type_is_byte_ptr 迁入后的 MIR body 计数"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_type_is_i32_ptr .*body_stmts=2 reason=pending_core_body' \
    "subset doc 缺少 native_build_type_is_byte_ptr 迁入后的下一 pending frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_type_is_byte_ptr\(type_node: &ASTNode\) i32' \
    "源码缺少 native_build_type_is_byte_ptr helper"
require_pattern "$BUILD_DRIVER_SRC" 'type_node\.type != ASTNodeType\.AST_TYPE_POINTER' \
    "源码缺少 pointer guard"
require_pattern "$BUILD_DRIVER_SRC" 'return native_build_type_is_byte\(type_node\.type_pointer_pointed_type\);' \
    "源码缺少 byte pointed-type helper-call return"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_type_is_byte_ptr_contract: ok"
