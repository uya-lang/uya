#!/usr/bin/env bash

# Native build-seed 边界：固定 native_build_decl_is_identity_generic_i32_fn(...)
# 9 statement helper 的 CoreBody/PortableMIR body-complete 合同。

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
require_pattern "$SUBSET_DOC" '^## `native_build_decl_is_identity_generic_i32_fn\(\.\.\.\)` Body Complete Contract' \
    "subset doc 缺少 native_build_decl_is_identity_generic_i32_fn 合同"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_decl_is_identity_generic_i32_fn .*body_stmts=9 reason=pending_core_body' \
    "subset doc 缺少当前 native_build_decl_is_identity_generic_i32_fn pending frontier"
require_pattern "$SUBSET_DOC" 'decl\.fn_decl_type_params == null \|\| decl\.fn_decl_type_param_count != 1' \
    "subset doc 缺少 type-param guard"
require_pattern "$SUBSET_DOC" 'const type_param_name: &byte = decl\.fn_decl_type_params\[0\]\.name;' \
    "subset doc 缺少 type_param_name local"
require_pattern "$SUBSET_DOC" 'const param: &ASTNode = decl\.fn_decl_params\[0\];' \
    "subset doc 缺少 param local"
require_pattern "$SUBSET_DOC" 'native_build_type_named_equals\(param\.var_decl_type, type_param_name\) == 0' \
    "subset doc 缺少 param type-name guard"
require_pattern "$SUBSET_DOC" 'native_build_type_named_equals\(decl\.fn_decl_return_type, type_param_name\) == 0' \
    "subset doc 缺少 return type-name guard"
require_pattern "$SUBSET_DOC" 'return native_build_decl_returns_param_directly\(decl, param\.var_decl_name\);' \
    "subset doc 缺少 tail identity helper-call"
require_pattern "$SUBSET_DOC" 'native_hosted_reachable_body_complete: function=native_build_decl_is_identity_generic_i32_fn prefix_stmts=9 reason=body_complete' \
    "subset doc 缺少 body-complete frontier"
require_pattern "$SUBSET_DOC" 'native_hosted_coreir_preflight: status=0 verifier_error=0 functions=[0-9]+ core_bodies=42 pending_bodies=[0-9]+' \
    "subset doc 缺少 native_build_decl_is_identity_generic_i32_fn 迁入后的 CoreBody 计数"
require_pattern "$SUBSET_DOC" 'native_hosted_preflight: status=0 verifier_error=0 mir_extern_functions=[0-9]+ mir_body_functions=41' \
    "subset doc 缺少 native_build_decl_is_identity_generic_i32_fn 迁入后的 MIR body 计数"
require_pattern "$SUBSET_DOC" 'native_hosted_pending_body_frontier: function=native_build_decl_is_two_i32_param_fn .*body_stmts=7 reason=pending_core_body' \
    "subset doc 缺少 native_build_decl_is_identity_generic_i32_fn 迁入后的下一 frontier"

require_pattern "$BUILD_DRIVER_SRC" 'fn native_build_decl_is_identity_generic_i32_fn\(decl: &ASTNode\) i32' \
    "源码缺少 native_build_decl_is_identity_generic_i32_fn helper"
require_pattern "$BUILD_DRIVER_SRC" 'native_build_type_named_equals\(param\.var_decl_type, type_param_name\) == 0' \
    "源码缺少 param type-name guard"
require_pattern "$BUILD_DRIVER_SRC" 'return native_build_decl_returns_param_directly\(decl, param\.var_decl_name\);' \
    "源码缺少 tail identity helper-call"
script_name="${0##*/}"
if grep -Eq "$script_name" "$STAGE1_TEST"; then
    echo "错误: stage1 不应重新聚合已归档 helper 合同" >&2
    echo "文件: $STAGE1_TEST" >&2
    exit 1
fi

echo "verify_native_decl_is_identity_generic_i32_fn_contract: ok"
